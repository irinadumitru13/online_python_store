FROM python:3.6

# Expose 5000 port for Flask
EXPOSE 5000

WORKDIR /FashionStore
ADD . /FashionStore/

# Set exec perm
RUN chmod +x /FashionStore/run.sh

# Install python requirements
RUN pip install -r /FashionStore/requirements.txt

ENTRYPOINT python /FashionStore/app.py
