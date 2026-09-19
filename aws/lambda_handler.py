"""Production AWS Lambda entry point for the single FastAPI application."""

from mangum import Mangum

from aws.server import app

handler = Mangum(app, lifespan="off")
