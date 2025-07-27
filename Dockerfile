# Multi-stage build for Maestro

# Stage 1: Build the Maestro codebase
FROM --platform=$BUILDPLATFORM eclipse-temurin:17-jdk AS builder

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

# Build the maestro-cli component and create the distribution zip
RUN ./gradlew --no-daemon \
    -Pandroid.aapt2.use.pipeline=true \
    -Pandroid.enableR8.fullMode=false \
    :maestro-cli:installDist :maestro-cli:distZip

# Stage 2: Create the runtime image
FROM eclipse-temurin:17-jdk

# Install unzip
RUN apt-get update && apt-get install -y \
    unzip \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the pre-built maestro.zip file from the builder stage
COPY --from=builder /app/maestro-cli/build/distributions/maestro.zip .

# Unzip the file
RUN unzip maestro.zip && \
    rm maestro.zip

# Add maestro/bin to PATH
ENV PATH="/app/maestro/bin:${PATH}"

# Verify installation
RUN maestro --version

# Expose the port that maestro-studio will run on
EXPOSE 8000

# Set the entry point to run maestro-studio
#ENTRYPOINT ["/app/maestro/bin/maestro", "studio"]
CMD ["maestro", "studio"]
# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1