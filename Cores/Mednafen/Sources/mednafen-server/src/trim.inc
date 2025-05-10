// Remove whitespace from beginning of string
void ltrim(char *string)
{
 int32 di, si;
 bool InWhitespace = true;

 di = si = 0;

 while(string[si])
 {
  if(InWhitespace && (string[si] == ' ' || string[si] == '\r' || string[si] == '\n' || string[si] == '\t' || 
string[si] == 0x0b))
  {

  }
  else
  {
   InWhitespace = false;
   string[di] = string[si];
   di++;
  }
  si++;
 }
 string[di] = 0;
}

// Remove whitespace from end of string
void rtrim(char *string)
{
 int32 len = strlen(string);

 if(len)
 {
  for(int32 x = len - 1; x >= 0; x--)
  {
   if(string[x] == ' ' || string[x] == '\r' || string[x] == '\n' || string[x] == '\t' || string[x] == 0x0b)
    string[x] = 0;
   else
    break;
  }
 }
}

void trim(char *string)
{
 rtrim(string);
 ltrim(string);
}


