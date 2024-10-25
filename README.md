 **Flask Microservice**
Welcome! This microservice is a simple Flask application that displays the message:

"Hello, this is Vatsal here, trying to deploy this."

Instructions to Set Up Locally
Requirements
Python 3.8
Docker Desktop
Setup Steps

Install the required Python packages:
pip install -r requirements.txt

Navigate to the directory containing the Dockerfile (root directory).
Build the Docker image:
docker build -t flask-app .

Run the Docker container:
docker run -p 5000:5000 flask-app

Accessing the Application
Once the container is running, you can access the Flask application at http://localhost:5000.

Deployed Website
You can also visit the deployed version of this microservice at http://35.200.243.53:80.
