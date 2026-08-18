import os
files = [
  ".gitignore",
  "Dockerfile",
  "README.md",
  "app.py",
  "docker-compose.yaml",
  "main.py",
  "pyproject.toml",
  "requirement.txt",
  "setup.sh",
]

for file in files:
  with open(file, "w") as f:
    #Populate pyproject.toml with default content
    if file == "pyproject.toml":
      f.write("""# ============================================
      # What is TOML file?
      #
      # if is a configuration file used by modern python project
      # to store project related information in a clean and 
      # readble format.
      # why do we need it
      #
      # Istead of keeping project metadata, dependencies, python 
      # version, package name, etc. in different places, we keep # everything together inside pyproject.toml.
      #
      # Most modern python tools(such as uv, Poetry, Hatch and #PDM) automatically read this file to understand how the #project should be built and what dependencies need to be # installed.
      #
      #
      [project]
      name ="ollama-aws-deployment"
      version ="0.1.0
      description ="Add your description here"
      readme ="README"
      requires-python =">=3.10"
      
      
      dependencies =[
      "fastapi==0.115.5",
      "httpx==0.27.2",
      "pydantic==2.10.3",
      "uvicorn[standard]==0.32.1",
      ]
    """)
      print(f"Created:{file}")



