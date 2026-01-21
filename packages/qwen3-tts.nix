{ pkgs, ... }:

let
  python = pkgs.python3;
in
python.pkgs.buildPythonPackage {
  pname = "qwen3-tts";
  version = "0.1.0"; # adjust if tags change

  src = pkgs.fetchFromGitHub {
    owner = "QwenLM";
    repo = "Qwen3-TTS";
    rev = "main"; # or a commit hash for reproducibility
    sha256 = "sha256-FDvUr4d7jnv6Lqt6mH9pwPqCRQPKToFkpN1WNVBDt1o=";
  };

  # The project uses pyproject.toml
  format = "pyproject";

  nativeBuildInputs = with python.pkgs; [
    setuptools
    wheel
  ];

  propagatedBuildInputs = with python.pkgs; [
    torch
    numpy
    scipy
    soundfile
    librosa
    transformers
    accelerate
    sentencepiece
    pyyaml
    tqdm
  ];

  # Skip tests (they may try to download models or need GPU)
  doCheck = false;

  pythonImportsCheck = [
    "qwen_tts"
  ];

  meta = with pkgs.lib; {
    description = "Qwen3 Text-to-Speech";
    homepage = "https://github.com/QwenLM/Qwen3-TTS";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
