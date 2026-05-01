class InvoluteTorch < Formula
  desc "Hardware-accelerated CBO library for manifold-constrained optimization — LibTorch backend"
  homepage "https://github.com/c0rmac/involute"
  url "https://github.com/c0rmac/involute/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "8fe6bd283a61b320c92db2eadb45faa645bf5debaedc3fcff9d6ac50932aeeb5"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "libomp"
  depends_on "pytorch"
  depends_on "abseil"
  depends_on "c0rmac/homebrew-isomorphism/isomorphism-torch"
  depends_on "c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler-torch"

  def install
    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism-torch"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler-torch"].opt_prefix
    torch_prefix   = Formula["pytorch"].opt_prefix
    abseil_prefix  = Formula["abseil"].opt_prefix

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DUSE_TORCH=ON",
      "-DCMAKE_PREFIX_PATH=#{iso_prefix};#{sampler_prefix};#{torch_prefix};#{abseil_prefix};#{HOMEBREW_PREFIX}",
      "-Dabsl_DIR=#{abseil_prefix}/lib/cmake/absl",
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism-torch"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler-torch"].opt_prefix
    torch          = Formula["pytorch"].opt_prefix

    (testpath/"test.cpp").write <<~EOS
      #include <involute/solvers/isotropic/so_isotropic_solver_cmaes.hpp>
      #include <involute/core/math.hpp>
      #include <memory>

      using namespace involute;
      using namespace involute::core;
      using namespace involute::solvers;

      int main() {
          FuncObj cost([](const Tensor& X) {
              Tensor I = math::eye(3, DType::Float32);
              return math::sum(math::square(math::subtract(X, I)), {1, 2});
          });

          SOIsotropicSolverCMAESConfig cfg{
              .N           = 50,
              .d           = 3,
              .convergence = std::make_shared<MaxStepsCriterion>(20),
          };

          SOIsotropicSolverCMAES solver(cfg);
          CBOResult result = solver.solve(&cost);
          return result.min_energy < 1.0 ? 0 : 1;
      }
    EOS

    system ENV.cxx, "-std=c++20",
           "test.cpp",
           "-I#{include}",
           "-I#{iso_prefix}/include",
           "-I#{sampler_prefix}/include",
           "-I#{torch}/include",
           "-I#{torch}/include/torch/csrc/api/include",
           "-L#{lib}",            "-linvolute",
           "-L#{iso_prefix}/lib", "-lisomorphism_torch",
           "-L#{sampler_prefix}/lib",
           "-L#{torch}/lib", "-ltorch", "-ltorch_cpu", "-lc10",
           "-o", "test"
    system "./test"
  end
end
