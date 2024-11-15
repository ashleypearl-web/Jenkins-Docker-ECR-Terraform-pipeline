# Start from the official Ubuntu base image
FROM ubuntu:20.04

# Metadata
LABEL "Author"="Ashley"
LABEL "techConProject"="app"

# Install required packages
RUN apt-get update -y && \
    apt-get install -y \
    wget \
    unzip \
    nginx \
    && apt-get clean

# Set the working directory
WORKDIR /usr/share/nginx/html

# Download the template zip from Tooplate
RUN wget https://www.tooplate.com/zip-templates/2117_infinite_loop.zip

# Unzip the template into the Nginx root directory
RUN unzip -o 2117_infinite_loop.zip && \
    rm 2117_infinite_loop.zip

# Copy custom nginx.conf to configure Nginx inside the container
COPY nginx.conf /etc/nginx/nginx.conf

# Expose the necessary ports (8080 and 8090)
EXPOSE 8080 8090

# Start Nginx in the foreground (as required by Docker containers)
CMD ["nginx", "-g", "daemon off;"]
