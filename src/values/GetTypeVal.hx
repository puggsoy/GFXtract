package values;

class GetTypeVal extends Value 
{
	public var value(default, null):GetType;
	
	public function new(v:GetType)
	{
		super();
		value = v;
	}
}

enum GetType
{
	Byte;
	Short;
	ThreeByte;
	Long;
	/*LongLong;
	StringG;
	ASize;
	FileName;
	BaseName;
	FilePath;
	FullName;
	FullBaseName;
	Extension;*/
}