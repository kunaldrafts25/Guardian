"""Production AWS Lambda entry point for the single FastAPI application."""

import pathlib
import sys
import types

if "aws" not in sys.modules:
    _pkg = types.ModuleType("aws")
    _pkg.__path__ = [str(pathlib.Path(__file__).resolve().parent)]
    sys.modules["aws"] = _pkg

from mangum import Mangum

from aws.server import app

handler = Mangum(app, lifespan="off")

