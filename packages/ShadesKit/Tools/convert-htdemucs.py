"""Converts HTDemucs (Meta, MIT) to the CoreML model StemSeparator runs: HTDemucs.mlmodelc.

The STFT is left out: Swift makes the spectrogram (StemSpectrogram) and turns the model's
spectrogram back into sound. The network takes one 7.8 s segment as `mix` [1, 2, 343980] and
its spectrogram as `spectrogram` [1, 4, 2048, 336] (left real, left imaginary, right real, right
imaginary), and returns all four sources (drums, bass, other, vocals) as `spectrogram_out`
[1, 4, 4, 2048, 336] and `waveform_out` [1, 4, 2, 343980]. It computes in half precision.

Afterwards it runs the compiled model on the GPU beside PyTorch on the same speech-over-chord
segment and fails unless every source is within 0.2% of PyTorch's.

Run on a Mac with Python 3.11, in a venv outside the repo:

    uv venv --python 3.11 /tmp/htdemucs-venv
    VIRTUAL_ENV=/tmp/htdemucs-venv uv pip install torch==2.7.0 coremltools==9.0 \
        demucs==4.1.0 numpy==1.26.4
    /tmp/htdemucs-venv/bin/python convert-htdemucs.py <output folder>

The weights are Meta's original `htdemucs` release (signature 955717e8), downloaded from
dl.fbaipublicfiles.com and checked against the hash in their file name.
"""

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from demucs.htdemucs import HTDemucs
from demucs.states import load_model
from einops import rearrange

WEIGHTS = "https://dl.fbaipublicfiles.com/demucs/hybrid_transformer/955717e8-8726e21a.th"
SAMPLE_RATE = 44100
SEGMENT = 343_980
FRAMES = 336
TOLERANCE = 0.002


class Network(torch.nn.Module):
    """HTDemucs.forward between its STFT and its inverse STFT, for exactly one segment."""

    def __init__(self, model: HTDemucs):
        super().__init__()
        self.model = model

    def forward(self, mix, spectrogram):
        m = self.model
        x = spectrogram
        B, C, Fq, T = x.shape
        mean = x.mean(dim=(1, 2, 3), keepdim=True)
        std = x.std(dim=(1, 2, 3), keepdim=True)
        x = (x - mean) / (1e-5 + std)
        xt = mix
        meant = xt.mean(dim=(1, 2), keepdim=True)
        stdt = xt.std(dim=(1, 2), keepdim=True)
        xt = (xt - meant) / (1e-5 + stdt)

        saved, saved_t, lengths, lengths_t = [], [], [], []
        for idx, encode in enumerate(m.encoder):
            lengths.append(x.shape[-1])
            inject = None
            if idx < len(m.tencoder):
                lengths_t.append(xt.shape[-1])
                tenc = m.tencoder[idx]
                xt = tenc(xt)
                if not tenc.empty:
                    saved_t.append(xt)
                else:
                    inject = xt
            x = encode(x, inject)
            if idx == 0 and m.freq_emb is not None:
                frs = torch.arange(x.shape[-2], device=x.device)
                emb = m.freq_emb(frs).t()[None, :, :, None].expand_as(x)
                x = x + m.freq_emb_scale * emb
            saved.append(x)

        if m.bottom_channels:
            f = x.shape[2]
            x = rearrange(x, "b c f t-> b c (f t)")
            x = m.channel_upsampler(x)
            x = rearrange(x, "b c (f t)-> b c f t", f=f)
            xt = m.channel_upsampler_t(xt)
        x, xt = m.crosstransformer(x, xt)
        if m.bottom_channels:
            x = rearrange(x, "b c f t-> b c (f t)")
            x = m.channel_downsampler(x)
            x = rearrange(x, "b c (f t)-> b c f t", f=f)
            xt = m.channel_downsampler_t(xt)

        for idx, decode in enumerate(m.decoder):
            x, pre = decode(x, saved.pop(-1), lengths.pop(-1))
            offset = m.depth - len(m.tdecoder)
            if idx >= offset:
                tdec = m.tdecoder[idx - offset]
                length_t = lengths_t.pop(-1)
                if tdec.empty:
                    xt, _ = tdec(pre[:, :, 0], None, length_t)
                else:
                    xt, _ = tdec(xt, saved_t.pop(-1), length_t)

        S = len(m.sources)
        x = x.view(B, S, -1, Fq, T) * std[:, None] + mean[:, None]
        xt = xt.view(B, S, -1, SEGMENT) * stdt[:, None] + meant[:, None]
        return x, xt


def load_htdemucs() -> HTDemucs:
    package = torch.hub.load_state_dict_from_url(WEIGHTS, map_location="cpu", check_hash=True)
    model = load_model(package)
    model.eval()
    assert int(model.segment * model.samplerate) == SEGMENT, model.segment
    assert model.sources == ["drums", "bass", "other", "vocals"], model.sources
    assert model.cac and model.use_train_segment and model.crosstransformer
    return model


def spectrogram(model: HTDemucs, mix: torch.Tensor) -> torch.Tensor:
    return model._magnitude(model._spec(mix))


def convert(model: HTDemucs, folder: Path) -> Path:
    network = Network(model).eval()
    mix = torch.randn(1, 2, SEGMENT) * 0.1
    # The fused attention kernel PyTorch picks for inference has no CoreML equivalent.
    torch.backends.mha.set_fastpath_enabled(False)
    with torch.no_grad():
        traced = torch.jit.trace(network, (mix, spectrogram(model, mix)))
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="mix", shape=(1, 2, SEGMENT), dtype=np.float32),
            ct.TensorType(name="spectrogram", shape=(1, 4, 2048, FRAMES), dtype=np.float32),
        ],
        outputs=[
            ct.TensorType(name="spectrogram_out", dtype=np.float16),
            ct.TensorType(name="waveform_out", dtype=np.float16),
        ],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        compute_units=ct.ComputeUnit.CPU_AND_GPU,
        minimum_deployment_target=ct.target.macOS15,
    )
    mlmodel.short_description = "HTDemucs (Meta, MIT) without its STFT, for Shades"
    package = folder / "HTDemucs.mlpackage"
    mlmodel.save(str(package))
    return Path(ct.utils.compile_model(str(package), str(folder / "HTDemucs.mlmodelc")))


def speech_over_chord() -> torch.Tensor:
    """One segment of the Mac's voice over an A major chord, like StemSeparatorTests."""
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "speech.wav"
        text = "Shades separates the voice from the music behind it. " * 2
        subprocess.run(
            ["say", "-o", str(path), f"--data-format=LEI16@{SAMPLE_RATE}", text], check=True
        )
        with wave.open(str(path)) as file:
            speech = np.frombuffer(file.readframes(file.getnframes()), dtype=np.int16)
    speech = np.resize(speech.astype(np.float32) / 32768, SEGMENT)
    time = np.arange(SEGMENT) / SAMPLE_RATE
    chord = sum(np.sin(2 * np.pi * pitch * time) * 0.08 for pitch in (220.0, 277.2, 329.6))
    mixed = torch.from_numpy((speech + chord).astype(np.float32))
    return mixed.expand(1, 2, SEGMENT).contiguous()


def check(model: HTDemucs, compiled: Path) -> bool:
    mix = speech_over_chord()
    with torch.no_grad():
        reference = model(mix)
    z = model._spec(mix)
    coreml = ct.models.CompiledMLModel(str(compiled), compute_units=ct.ComputeUnit.CPU_AND_GPU)
    outputs = coreml.predict({
        "mix": mix.numpy(),
        "spectrogram": model._magnitude(z).numpy(),
    })
    spectrum = torch.from_numpy(outputs["spectrogram_out"].astype(np.float32))
    waveform = torch.from_numpy(outputs["waveform_out"].astype(np.float32))
    separated = waveform + model._ispec(model._mask(z, spectrum), SEGMENT)
    passed = True
    # Shades keeps vocals as the voice and sums the rest into music, so those are what's
    # compared: drums and bass are nearly silent here, so their own error means little.
    for stem, sources in (("voice", [3]), ("music", [0, 1, 2])):
        ours = separated[0, sources].sum(0)
        theirs = reference[0, sources].sum(0)
        error = ((ours - theirs).norm() / theirs.norm()).item()
        print(f"{stem}: {error:.4%} from PyTorch")
        passed = passed and error <= TOLERANCE
    return passed


def main() -> None:
    folder = Path(sys.argv[1])
    folder.mkdir(parents=True, exist_ok=True)
    model = load_htdemucs()
    compiled = convert(model, folder)
    print(f"compiled {compiled}")
    if not check(model, compiled):
        sys.exit(f"the converted model is more than {TOLERANCE:.1%} from PyTorch")


if __name__ == "__main__":
    main()
