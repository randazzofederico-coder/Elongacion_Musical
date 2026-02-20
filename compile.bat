@echo off

echo Compilando Testbench del Vocoder...

:: Intenta con clang++ si el NDK de Android/Studio lo puso en el PATH,
:: O con g++ si MinGW está instalado.
WHERE clang++ >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    echo Usando Clang++...
    clang++ -O3 -std=c++17 -Wall vocoder_testbench.cpp -o vocoder_test.exe
    IF %ERRORLEVEL% NEQ 0 (
        echo Error de compilacion.
        exit /b %ERRORLEVEL%
    )
    echo Compilacion exitosa.
    exit /b 0
)

WHERE g++ >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    echo Usando GCC...
    g++ -O3 -std=c++17 -Wall vocoder_testbench.cpp -o vocoder_test.exe
    IF %ERRORLEVEL% NEQ 0 (
        echo Error de compilacion.
        exit /b %ERRORLEVEL%
    )
    echo Compilacion exitosa.
    exit /b 0
)

echo ERROR: No se encontro ningun compilador C++ (ni clang++ ni g++).
echo Avisame en el chat asi te digo como usar Python y Numpy en su lugar.
exit /b 1
