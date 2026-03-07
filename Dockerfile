# Use lightweight nginx image
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy application build files
COPY dist/ /usr/share/nginx/html

# Expose container port
EXPOSE 80

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]
