FROM python:3.11-slim

# Create a non-root user and group
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Set working directory
WORKDIR /app

# Copy application files
COPY app/ /app/
COPY app/requirements.txt /app/

# Install dependencies (still as root, then switch)
RUN pip install --no-cache-dir -r requirements.txt \
    && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 8080

# Run the application
CMD ["python", "main.py"]