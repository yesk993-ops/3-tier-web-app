# Dockerfile for React Application

# Use the official Node.js image as a parent image
FROM node:14

# Set the working directory in the container
WORKDIR /app

# Copy the package.json and package-lock.json files
COPY package*.json ./

# Install the dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the React application
RUN npm run build

# Serve the application using serve
RUN npm install -g serve

# Define the command to run the application
CMD ["serve", "-s", "build"]

# Expose the port on which the app runs
EXPOSE 3000
