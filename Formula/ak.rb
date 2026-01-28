class Ak < Formula
  desc "ADB extensions kit - Essential ADB utilities for Android development"
  homepage "https://github.com/luminousvault/adb-extensions"
  url "https://github.com/luminousvault/adb-extensions/releases/download/v1.1.4/adb-extensions-v1.1.4.tar.gz"
  sha256 "565c7d54c1a2ef3f2c6ecf959b9555709bbb69d1fd6db9eb7cf6e89c17a8e149"
  license "MIT"
  version "1.1.4"

  # depends_on "android-platform-tools"  # adb 의존성

  def install
    # 쉘 스크립트 설치
    bin.install "build/ak" => "ak"
    # Completion 설치
    zsh_completion.install "build/completions/_ak"
  end
  
  def caveats
    <<~EOS
        ⚠️ IMPORTANT: To enable tab completion, restart your terminal
    EOS
  end

  test do
    # 버전 체크
    assert_match "1.0.3", shell_output("#{bin}/ak --version")
    
    # 도움말 체크
    assert_match "ADB extensions kit", shell_output("#{bin}/ak --version")
    
    # install 커맨드 체크
    assert_match "install", shell_output("#{bin}/ak --help")
  end
end
