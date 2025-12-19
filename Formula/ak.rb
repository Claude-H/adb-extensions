class Ak < Formula
  desc "ADB extensions kit - Essential ADB utilities for Android development"
  homepage "https://github.com/luminousvault/adb-extensions"
  url "https://github.com/luminousvault/adb-extensions/releases/download/v1.0.1/adb-extensions-v1.0.1.tar.gz"
  sha256 "3ba0d889b3374e3f7210645716306eafee9ae495637c6989fe7c84e21ac23d2c"
  license "MIT"
  version "1.0.1"

  # depends_on "android-platform-tools"  # adb 의존성

  def install
    # 빌드된 단일 파일 설치
    bin.install "build/ak.bin" => "ak"
    # 표준 실행 파일
    chmod 0755, bin/"ak"
    # Completion 설치
    zsh_completion.install "build/completions/_ak"
  end

  test do
    # 버전 체크
    assert_match "1.0.0", shell_output("#{bin}/ak --version")
    
    # 도움말 체크
    assert_match "ADB extensions kit", shell_output("#{bin}/ak --version")
    
    # install 커맨드 체크
    assert_match "install", shell_output("#{bin}/ak --help")
  end
end
