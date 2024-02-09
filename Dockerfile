# Use Python 3.10 as a parent image
FROM python:3.10-alpine

# Copy requirements.txt to the container at /app
COPY requirements.txt /app/requirements.txt

# Set the working directory in the container to /app
WORKDIR /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY . /app

# Run script.py when the container launches
CMD ["python", "script.py"]
