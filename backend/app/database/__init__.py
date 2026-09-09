from flask import Flask

from app.database.manager import DatabaseManager as DBM

def create_app():
    app=Flask(__name__)
    
    database=DBM("backend/config/tables.yaml")
    
    database.initialize()
    
    return app