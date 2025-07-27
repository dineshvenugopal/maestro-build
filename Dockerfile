# Single stage build and runtime image
FROM eclipse-temurin:19-jdk

# Install required tools (git, curl, etc.)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 16.14.0
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@8.5.0

# Set up Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

# Download and install Android SDK
RUN mkdir -p ${ANDROID_HOME} && \
    cd ${ANDROID_HOME} && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip && \
    unzip commandlinetools-linux-*_latest.zip && \
    rm commandlinetools-linux-*_latest.zip && \
    mkdir -p cmdline-tools/latest && \
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true && \
    yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.0"

# Set working directory
WORKDIR /app

# Clone the Maestro repository (main branch)
RUN git clone https://github.com/mobile-dev-inc/Maestro.git . --branch main

# Make gradlew executable
RUN chmod +x ./gradlew

# Build the complete project and install maestro-cli
RUN ./gradlew --no-daemon build :maestro-cli:installDist

# Expose the port that maestro-studio will run on
# Note: The actual port is dynamically assigned, but we'll expose a default port
EXPOSE 8000

# Set the entry point to run maestro-studio
ENTRYPOINT ["/app/maestro-cli/build/install/maestro/bin/maestro", "studio", "--no-window"]

# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1