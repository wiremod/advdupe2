#include "GarrysMod/Lua/Interface.h"
#include <stdio.h>
#include<iostream>
#include<fstream>

using namespace GarrysMod::Lua;

char tempChar;
short tempShort;
double tempDouble;
std::string tempString;
std::ofstream file;

int Open( lua_State* state )
{
	file.open("garrysmod/data/ad2temp.txt", std::ios::out | std::ios::binary);
	if(file.is_open())
		LUA->PushBool(true);
	else
		LUA->PushBool(false);
	return 1;
}

int Close( lua_State* state )
{
	file.close();
	return 1;
}

int WriteByte( lua_State* state )
{
	tempChar = (char)LUA->GetNumber( 1 );
	file.write(reinterpret_cast<char*>(&tempChar), sizeof(char));
	return 1;
}

int WriteShort( lua_State* state )
{
	tempShort = (short)LUA->GetNumber( 1 );
	file.write(reinterpret_cast<char*>(&tempShort), sizeof(short));
	return 1;
}

int WriteDouble( lua_State* state )
{
	tempDouble = LUA->GetNumber( 1 );
	file.write(reinterpret_cast<char*>(&tempDouble), sizeof(double));
	return 1;
}

int WriteString( lua_State* state )
{
	tempString = LUA->GetString(1);
	file.write(tempString.c_str(), tempString.size());
	return 1;
}

GMOD_MODULE_OPEN()
{
	LUA->PushSpecial( GarrysMod::Lua::SPECIAL_GLOB );
	LUA->PushString( "AdvDupe2_OpenStream" );
	LUA->PushCFunction( Open );
	LUA->SetTable( -3 );

	LUA->PushSpecial( GarrysMod::Lua::SPECIAL_GLOB );
	LUA->PushString( "AdvDupe2_CloseStream" );
	LUA->PushCFunction( Close );
	LUA->SetTable( -3 );

	LUA->PushSpecial( GarrysMod::Lua::SPECIAL_GLOB );
	LUA->PushString( "AdvDupe2_WriteByte" );
	LUA->PushCFunction( WriteByte );
	LUA->SetTable( -3 );

	LUA->PushSpecial( GarrysMod::Lua::SPECIAL_GLOB );
	LUA->PushString( "AdvDupe2_WriteShort" );
	LUA->PushCFunction( WriteShort );
	LUA->SetTable( -3 );

	LUA->PushSpecial( GarrysMod::Lua::SPECIAL_GLOB );
	LUA->PushString( "AdvDupe2_WriteDouble" );
	LUA->PushCFunction( WriteDouble );
	LUA->SetTable( -3 );

	LUA->PushSpecial( GarrysMod::Lua::SPECIAL_GLOB );
	LUA->PushString( "AdvDupe2_WriteString" );
	LUA->PushCFunction( WriteString );
	LUA->SetTable( -3 );

	return 0;
}

GMOD_MODULE_CLOSE()
{
	return 0;
}