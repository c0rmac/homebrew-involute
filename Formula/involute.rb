class Involute < Formula
  desc "Hardware-accelerated CBO library for manifold-constrained optimization"
  homepage "https://github.com/c0rmac/involute"
  url "https://github.com/c0rmac/involute/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "8fe6bd283a61b320c92db2eadb45faa645bf5debaedc3fcff9d6ac50932aeeb5"
  license "MIT"

  # ---------------------------------------------------------------------------
  # Backend options — exactly one must be specified.
  #
  # Involute delegates all tensor operations to isomorphism. You must choose
  # the backend that matches your hardware and toolchain.
  #
  # Usage:
  #   brew install c0rmac/homebrew-involute/involute --with-mlx   # Apple Silicon / Metal
  #   brew install c0rmac/homebrew-involute/involute --with-torch # LibTorch / PyTorch
  # ---------------------------------------------------------------------------
  option "with-mlx",   "Use the Apple MLX (Metal) backend (Apple Silicon)"
  option "with-torch", "Use the LibTorch backend"

  # ---------------------------------------------------------------------------
  # Hard build-time dependencies (always required)
  # ---------------------------------------------------------------------------
  depends_on "cmake" => :build
  depends_on "libomp"   # required by riemannian-gaussian-sampler's OpenMP threading

  # Backend runtime libraries
  depends_on "mlx"     if build.with?("mlx")
  depends_on "pytorch" if build.with?("torch")
  depends_on "abseil"  if build.with?("torch")  # transitive dep of LibTorch protobuf

  # ---------------------------------------------------------------------------
  # Install
  #
  # isomorphism and riemannian-gaussian-sampler are installed here rather than
  # declared as `depends_on` entries so that we can forward the chosen backend
  # option to isomorphism. Homebrew cannot propagate options across dependencies.
  # ---------------------------------------------------------------------------
  def install
    use_mlx   = build.with?("mlx")
    use_torch = build.with?("torch")

    unless use_mlx || use_torch
      odie "You must specify a backend: --with-mlx (Apple Silicon) or --with-torch (LibTorch)"
    end

    if use_mlx && use_torch
      odie "Only one backend may be selected at a time: --with-mlx or --with-torch"
    end

    # Ensure dependency taps are registered before resolving formulae.
    %w[c0rmac/homebrew-isomorphism c0rmac/homebrew-riemannian-gaussian-sampler].each do |tap|
      user, repo = tap.split("/")
      Tap.fetch(user, repo).install unless Tap.fetch(user, repo).installed?
    end

    # Install isomorphism with the selected backend. brew install is idempotent;
    # if it is already present with the correct backend this is a no-op.
    iso_args = ["brew", "install", "c0rmac/homebrew-isomorphism/isomorphism"]
    iso_args << "--with-mlx"   if use_mlx
    iso_args << "--with-torch" if use_torch
    system(*iso_args)

    # Install riemannian-gaussian-sampler (depends on isomorphism internally).
    system "brew", "install",
           "c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler"

    # Resolve installed prefixes now that dependencies are guaranteed to exist.
    iso_prefix     = Formula["c0rmac/homebrew-isomorphism/isomorphism"].opt_prefix
    sampler_prefix = Formula["c0rmac/homebrew-riemannian-gaussian-sampler/riemannian-gaussian-sampler"].opt_prefix

    cmake_prefix = "#{iso_prefix};#{sampler_prefix};#{HOMEBREW_PREFIX}"

    args = std_cmake_args + %W[
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
      -DCMAKE_PREFIX_PATH=#{cmake_prefix}
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
