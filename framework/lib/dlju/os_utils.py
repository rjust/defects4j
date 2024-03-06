""" Figure out which operating system is being used
"""
import platform

def isMacOsX():
    return platform.system() == "Darwin"

def isLinux():
    return platform.system() == "Linux"

def isWindows():
    return platform.system() == "Windows" or platform.system().lower().startswith("cygwin")
