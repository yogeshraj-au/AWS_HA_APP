#!/bin/bash

# Check if Java 8 is installed
if command -v java &> /dev/null; then
    if java -version 2>&1 | grep "1.8"; then
        echo "Java 8 is already installed."
    else
        echo "Java is installed but not version 8. Installing Java 8 now..."
        sudo apt update
        sudo apt install openjdk-8-jre -y
        echo "Java 8 has been installed."
    fi
else
    # Install Java 8
    echo "Java is not installed. Installing Java 8 now..."
    sudo apt update
    sudo apt install openjdk-8-jre -y
    echo "Java 8 has been installed."
fi


    # URL of the JAR file to download
    JAR_URL="http://example.com/"

    # Name of the JAR file
    JAR_FILE="backend.jar"

    # Directory path to check
    DIRECTORY_PATH="/opt/backend"

    # Check if directory exists
    if [ ! -d "$DIRECTORY_PATH" ]; then
        # Create directory
        echo "Creating directory..."
        mkdir -p "$DIRECTORY_PATH"
        echo "Directory created."
    else
        echo "Directory already exists."
    fi
    
    cd $DIRECTORY_PATH
    # Download the JAR file
    echo "Downloading JAR file from $JAR_URL..."
    wget -O $JAR_FILE $JAR_URL

    # Check if download succeeded
    if [ $? -eq 0 ]; then
        echo "JAR file downloaded successfully."
    else
        echo "Failed to download JAR file. Exiting..."
        exit 1
    fi

    # Set executable permission and run the JAR file
    echo "Set executable permission and running JAR file using Java..."
    chmod 777 $JAR_FILE
    java -jar $JAR_FILE
