#include <windows.h>
#include <stdio.h>
#include "asmbind.h";

struct PutSymbols_Position
{
	unsigned short x;
	unsigned short y;
	unsigned short width;
	unsigned short length = 0;
};

struct PutSymbols_Draw
{
	PutSymbols_Draw(
		CHAR_INFO const& charInfo,
		unsigned short height = 0
	)
		: symbol(unsigned(charInfo.Attributes) << 16 | unsigned(charInfo.Char.UnicodeChar))
		, height(height)
	{}

	unsigned int symbol;
	unsigned short height = 0;
};

extern "C" void Put_Symbols_Horizontal(CHAR_INFO * screenBuffer, PutSymbols_Position position, PutSymbols_Draw draw);
extern "C" void Put_Symbols_Region(CHAR_INFO * screenBuffer, PutSymbols_Position position, PutSymbols_Draw draw);

struct DrawRectangleParams
{
	unsigned short length;
};

extern "C" void Draw_Color_Rectangle(CHAR_INFO * screenBuffer, DrawRectangleParams params);

int main(void)
{
	HANDLE hStdout, hNewScreenBuffer;
	CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;

	hStdout = GetStdHandle(STD_OUTPUT_HANDLE);
	hNewScreenBuffer = CreateConsoleScreenBuffer(
		GENERIC_READ | GENERIC_WRITE,
		FILE_SHARE_READ | FILE_SHARE_WRITE,
		NULL,
		CONSOLE_TEXTMODE_BUFFER,
		NULL);
	if (hStdout == INVALID_HANDLE_VALUE ||
		hNewScreenBuffer == INVALID_HANDLE_VALUE)
	{
		printf("CreateConsoleScreenBuffer failed - (%d)\n", GetLastError());
		return 1;
	}

	if (!SetConsoleActiveScreenBuffer(hNewScreenBuffer))
	{
		printf("SetConsoleActiveScreenBuffer failed - (%d)\n", GetLastError());
		return 1;
	}

	if (!GetConsoleScreenBufferInfo(hNewScreenBuffer, &screenBufferInfo))
	{
		printf("GetConsoleScreenBufferInfo failed - (%d)\n", GetLastError());
		return 1;
	}

	auto& screenSize = screenBufferInfo.dwSize;
	unsigned screenBufferLength = int(screenSize.X) * int(screenSize.Y);
	CHAR_INFO* screenBuffer = new CHAR_INFO[screenBufferLength];

	{
		SMALL_RECT srctWriteRect{ 0, 0, screenSize.X - 1, screenSize.Y - 1 };
		for (int i = 0; i < screenBufferLength; ++i)
		{
			screenBuffer[i].Char.UnicodeChar = ' ';
			screenBuffer[i].Attributes = 0x0F;
		}

		auto success = WriteConsoleOutput(
			hNewScreenBuffer,
			screenBuffer,
			screenSize,
			{ 0, 0 },
			&srctWriteRect);
		if (!success)
		{
			printf("WriteConsoleOutput failed - (%d)\n", GetLastError());
			return 1;
		}
	}

	unsigned short width = screenSize.X;

	CHAR_INFO symbol{ L'Z', 0x0F };

	DrawRectangleParams colorReactParams{ width };

	Draw_Color_Rectangle(screenBuffer, colorReactParams);

	PutSymbols_Position putSymbolsParams{ 1, 1, width, 3 };
	PutSymbols_Draw putSymbolsDrawParam{ symbol, 4 };

	PutSymbols_Position regionPars{ 5, 2, width, 8 };

	Put_Symbols_Horizontal(screenBuffer, putSymbolsParams, putSymbolsDrawParam);
	Put_Symbols_Region(screenBuffer, regionPars, putSymbolsDrawParam);

	WriteConsoleOutput(
		hNewScreenBuffer,
		screenBuffer,
		screenSize,
		{ 0, 0 },
		&screenBufferInfo.srWindow);

	Sleep(500000);

	if (!SetConsoleActiveScreenBuffer(hStdout))
	{
		printf("SetConsoleActiveScreenBuffer failed - (%d)\n", GetLastError());
		return 1;
	}

	return 0;
}