class Involute < Formula
  desc "Hardware-accelerated CBO library for manifold-constrained optimization"
  homepage "https://github.com/c0rmac/involute"
  url "https://github.com/c0rmac/involute/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "deced2da64963487e318a33752e7debb901d04cd60ffab06c3bdd44999eaeebc" # Generate this after pushing your tag
  license "MIT"

  depends_on "cmake" => :build
  depends_on "mlx"

  depends_on :macos
  #conflicts_with "involute-sycl", because: "this version is optimized for Apple Silicon"

  def install
    # Ensure we are on Apple Silicon as per README requirements
    if Hardware::CPU.intel?
      odie "Involute currently only supports Apple Silicon (M-series) via MLX." [cite: 1]
    end

    args = %W[
      -DUSE_MLX=ON
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <involute/solvers/so_solver.hpp>
      #include <involute/core/objective.hpp>
      int main() {
          return 0;
      }
    EOS
    system ENV.cxx, "-std=c++20", "test.cpp", "-L#{lib}", "-linvolute", "-o", "test" [cite: 1]
    system "./test"
  end
end