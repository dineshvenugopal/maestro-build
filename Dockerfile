# Single stage build and runtime image
# Specify platform to ensure compatibility
FROM --platform=$BUILDPLATFORM eclipse-temurin:17-jdk

# Set ARG for build platform detection
ARG BUILDPLATFORM
ARG TARGETPLATFORM

# Install required tools (git, curl, etc.)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    libc6 \
    libstdc++6 \
    zlib1g \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 16.14.0
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@8.5.0

# Set up Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

# Download and install Android SDK with platform-aware architecture detection
RUN mkdir -p ${ANDROID_HOME} && \
    cd ${ANDROID_HOME} && \
    echo "Build platform: $BUILDPLATFORM" && \
    echo "Target platform: $TARGETPLATFORM" && \
    # Download the command line tools
    wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip && \
    unzip commandlinetools-linux-*_latest.zip && \
    rm commandlinetools-linux-*_latest.zip && \
    mkdir -p cmdline-tools/latest && \
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true && \
    # Create necessary configuration directories
    mkdir -p ~/.android && \
    touch ~/.android/repositories.cfg && \
    # Set Java options for cross-platform compatibility
    export JAVA_OPTS="-XX:+IgnoreUnrecognizedVMOptions" && \
    # Accept licenses with a more robust approach
    yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses > /dev/null || true && \
    # Install SDK components with architecture awareness
    sdkmanager --sdk_root=${ANDROID_HOME} "platform-tools" "platforms;android-33" "build-tools;33.0.0" && \
    # Verify installation
    ls -la ${ANDROID_HOME}/platform-tools/ && \
    ls -la ${ANDROID_HOME}/build-tools/

# Set working directory
WORKDIR /app

# Clone the Maestro repository (main branch)
RUN git clone https://github.com/mobile-dev-inc/Maestro.git . --branch main

# Make gradlew executable
RUN chmod +x ./gradlew

# Set environment variables for Gradle build
ENV JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF8 -XX:+IgnoreUnrecognizedVMOptions"
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.jvmargs='-Xmx4g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError'"
ENV ANDROID_AAPT_IGNORE="*.git:*.github:*.gitignore:*.kt:*.java:*.scala:*.groovy:*.gradle"

# Build and install only the maestro-cli component
RUN ./gradlew --no-daemon \
    -Pandroid.aapt2.use.pipeline=true \
    -Pandroid.enableR8.fullMode=false \
    :maestro-cli:installDist

# Expose the port that maestro-studio will run on
# Note: The actual port is dynamically assigned, but we'll expose a default port
EXPOSE 8000

# Set the entry point to run maestro-studio
ENTRYPOINT ["/app/maestro-cli/build/install/maestro/bin/maestro", "studio", "--no-window"]

# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1