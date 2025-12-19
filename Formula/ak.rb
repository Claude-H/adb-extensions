class Ak < Formula
  desc "ADB extensions kit - Essential ADB utilities for Android development"
  homepage "https://github.com/luminousvault/adb-extensions"
  url "https://github.com/luminousvault/adb-extensions/releases/download/v1.0.2/adb-extensions-v1.0.2.tar.gz"
  sha256 "df0000b9e6983ec8c0356a68b382d06622f1e29ecc6ac2adea214b114c9f4261"
  license "MIT"
  version "1.0.2"

  # depends_on "android-platform-tools"  # adb 의존성

  def install
    # 쉘 스크립트 설치
    bin.install "build/ak" => "ak"
    # Completion 설치
    zsh_completion.install "build/completions/_ak"
  end

  test do
    # 버전 체크
    assert_match "1.0.2", shell_output("#{bin}/ak --version")
    
    # 도움말 체크
    assert_match "ADB extensions kit", shell_output("#{bin}/ak --version")
    
    # install 커맨드 체크
    assert_match "install", shell_output("#{bin}/ak --help")
  end
end
