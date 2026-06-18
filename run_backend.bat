@echo off
cd /d symptrack_flutter\backend
pip install -r requirements.txt
python chat_server.py
pause
