class Involute < Formula
  desc "Hardware-accelerated CBO library for manifold-constrained optimization"
  homepage "https://github.com/c0rmac/involute" # Based on the tap name provided
  url "https://github.com/c0rmac/involute/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "deced2da64963487e318a33752e7debb901d04cd60ffab06c3bdd44999eaeebc"
  license "MIT" # Update if the project uses a different license

  depends_on "cmake" => :build
  depends_on "mlx"

  # The README specifies macOS Apple Silicon (M-series) exclusively
  depends_on :macos
  conflicts_with "involute-sycl", because: "this version is optimized for Apple Silicon"

  def install
    if Hardware::CPU.intel?
      odie "Involute currently only supports Apple Silicon (M-series) via MLX."
    end

    args = %w[
      -DBUILD_SHARED_LIBS=ON
      -DINVOLUTE_BUILD_EXAMPLES=OFF
      -DINVOLUTE_BUILD_TESTS=OFF
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # Simple test to check if the header is accessible and linkable
    (testpath/"test.cpp").write <<~EOS
      #include <involute/solvers/so_solver.hpp>
      #include <involute/core/objective.hpp>
      int main() {
          return 0;
      }
    EOS
    system ENV.cxx, "-std=c++17", "test.cpp", "-L#{lib}", "-linvolute", "-o", "test"
    system "./test"
  end
end