package statements;
import sys.io.FileInput;

interface Statement 
{
	public function execute(store:Store):Void;
	public function toString():String;
}