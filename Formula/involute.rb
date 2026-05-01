class Involute < Formula
  desc "Hardware-accelerated CBO library for manifold-constrained optimization"
  homepage "https://github.com/c0rmac/involute"
  url "https://github.com/c0rmac/involute/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "8fe6bd283a61b320c92db2eadb45faa645bf5debaedc3fcff9d6ac50932aeeb5"
  license "MIT"

  # ---------------------------------------------------------------------------
  # Backend options — exactly one must be specified.
  #
  # isomorphism must be installed separately with the matching backend flag
  # before installing involute:
  #
  #   brew tap c0rmac/homebrew-isomorphism
  #   brew install c0rmac/homebrew-isomorphism/isomorphism --with-mlx   # Apple Silicon
  #   brew install c0rmac/homebrew-isomorphism/isomorphism --with-torch  # LibTorch
  #
  # Then install involute with the same backend flag:
  #   brew install c0rmac/homebrew-involute/involute --with-mlx
  #   brew install c0rmac/homebrew-involute/involute --with-torch
  # ---------------------------------------------------------------------------
  option "with-mlx",   "Use the Apple MLX (Metal) backend (Apple Silicon)"
  option "with-torch", "Use the LibTorch backend"

  # ---------------------------------------------------------------------------
  # Dependencies
  # ---------------------------------------------------------------------------
  depends_on "cmake" => :build
  depends_on "libomp"   # required by riemannian-gaussian-sampler's OpenMP threading

  depends_on "c0rmac/homebrew-isomorphism/isomorphism"
  depends_on "c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler"

  # Backend runtime libraries
  depends_on "mlx"     if build.with?("mlx")
  depends_on "pytorch" if build.with?("torch")
  depends_on "abseil"  if build.with?("torch")  # transitive dep of LibTorch protobuf

  def install
    use_mlx   = build.with?("mlx")
    use_torch = build.with?("torch")

    unless use_mlx || use_torch
      odie "You must specify a backend: --with-mlx (Apple Silicon) or --with-torch (LibTorch)"
    end

    if use_mlx && use_torch
      odie "Only one backend may be selected at a time: --with-mlx or --with-torch"
    end

    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler"].opt_prefix

    args = std_cmake_args + %W[
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
    ]

    if use_torch
      torch_prefix  = Formula["pytorch"].opt_prefix
      abseil_prefix = Formula["abseil"].opt_prefix
      args << "-DUSE_TORCH=ON"
      args << "-DCMAKE_PREFIX_PATH=#{iso_prefix};#{sampler_prefix};#{torch_prefix};#{abseil_prefix};#{HOMEBREW_PREFIX}"
      args << "-Dabsl_DIR=#{abseil_prefix}/lib/cmake/absl"
    elsif use_mlx
      args << "-DUSE_MLX=ON"
      args << "-DCMAKE_PREFIX_PATH=#{iso_prefix};#{sampler_prefix};#{Formula["mlx"].opt_prefix};#{HOMEBREW_PREFIX}"
    end

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler"].opt_prefix

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
           "-L#{lib}",     "-linvolute",
           "-L#{iso_prefix}/lib",
           "-L#{sampler_prefix}/lib",
           "-o", "test"
    system "./test"
  end
end
