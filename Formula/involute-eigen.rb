class InvoluteEigen < Formula
  desc "Hardware-accelerated CBO library for manifold-constrained optimization — Eigen CPU backend"
  homepage "https://github.com/c0rmac/involute"
  url "https://github.com/c0rmac/involute/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "bfb102acbb07731482d3c354d11ae69fd6d0901869d5c5da4f8f298a7ad6f6a6"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "libomp"
  depends_on "eigen"
  depends_on "c0rmac/homebrew-isomorphism/isomorphism-eigen"
  depends_on "c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler-eigen"

  def install
    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism-eigen"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler-eigen"].opt_prefix
    eigen_prefix   = Formula["eigen"].opt_prefix

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DUSE_EIGEN=ON",
      "-DCMAKE_PREFIX_PATH=#{iso_prefix};#{sampler_prefix};#{eigen_prefix};#{HOMEBREW_PREFIX}",
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism-eigen"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler-eigen"].opt_prefix
    eigen          = Formula["eigen"].opt_include
    libomp         = Formula["libomp"].opt_prefix

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
           "-I#{eigen}/eigen3",
           "-L#{lib}",                "-linvolute",
           "-L#{sampler_prefix}/lib", "-lsampler",
           "-L#{iso_prefix}/lib",     "-lisomorphism_eigen",
           "-L#{libomp}/lib",         "-lomp",
           "-o", "test"
    system "./test"
  end
end
