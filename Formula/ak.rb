class Ak < Formula
  desc "ADB extensions kit - Essential ADB utilities for Android development"
  homepage "https://github.com/luminousvault/adb-extensions"
  url "https://github.com/luminousvault/adb-extensions/releases/download/v1.0.0/adb-extensions-v1.0.0.tar.gz"
  sha256 "878ec096dbd8569f2dd37c6b7cac10cabfc94d81ab55f8c093c6fc03af37d4bc"
  license "MIT"
  version "1.0.0"

  # depends_on "android-platform-tools"  # adb 의존성

  def install
    # 빌드된 단일 파일 설치
    bin.install "build/ak.bin" => "ak"
    
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
