unit JNIUtils;

{
  JNIUtils - utility methods for use with JNI.pas (JEDI).

  Written by Keith Wood (kbwood@iprimus.com.au)
  23 November 2002

  Updated by Remy Lebeau (remy@lebeausoftware.org)
  09 February 2011
}

interface

uses
  windows,
  Classes, SysUtils, Variants, JNI;

const
  ConstructorName = '<init>';
  InitializerName = '<clinit>';

procedure AddCommonJavaClass(const ClassName: UTF8String); overload;
procedure AddCommonJavaClass(const ClassName, Shortcut: UTF8String); overload;

function GetJavaType(const JType: UTF8String): UTF8String;
function GetJavaMethodSig(const JTypes: array of UTF8String): UTF8String; overload;
function GetJavaMethodSig(const MethodSig: UTF8String): UTF8String; overload;

function CreateObject(const JVM: TJNIEnv;
  const ClassName, ConstructorSig: UTF8String; const Args: array of const): JObject;
function GetFieldValue(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const FieldName, FieldType: UTF8String; const Static: Boolean = False): Variant;
function GetObjectFieldValue(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const FieldName, FieldType: UTF8String; const Static: Boolean = False): JObject;
function CallMethod(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const MethodName, MethodSig: UTF8String; const Args: array of const;
  const Static: Boolean = False): Variant;
function CallObjectMethod(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const MethodName, MethodSig: UTF8String; const Args: array of const;
  const Static: Boolean = False): JObject;

implementation

resourcestring
  ClassNotFound     = 'Cannot find class for object';
  ExistingShortcut  = 'Shortcut already registered for %s';
  FieldNotFound     = 'Cannot find field %s %s for object';
  MethodNotFound    = 'Cannot find method %s %s for object';
  NoObjectReturn    = 'Cannot return an object %s';
  NoPrimitiveReturn = 'Cannot return a primitive %s';
  UnknownFieldType  = 'Unknown field type %s';
  UnknownParamType  = 'Unknown parameter type for %d';

var
  CommonTypes: TStringList;

{ Add a class to the list of common Java types, thereby enabling the
  short form to be used in a signature. For example, 'java.lang.Boolean'
  is registered, meaning that you only need 'Boolean' in the signature.
  ClassName is the fully qualified name of the class. }
procedure AddCommonJavaClass(const ClassName: UTf8String);
var
  Index: Integer;
  Shortcut: UTF8String;
begin
  Shortcut := ClassName;
  for Index := Length(Shortcut) downto 1 do
    if Shortcut[Index] = '.' then
      Break;
  if Index > 0 then
    Shortcut := Copy(Shortcut, Index + 1, Length(Shortcut));
  AddCommonJavaClass(ClassName, Shortcut);
end;

{ Add a class to the list of common Java types, thereby enabling the
  short form to be used in a signature. For example, 'java.lang.Boolean'
  is registered, meaning that you only need 'Boolean' in the signature.
  ClassName is the fully qualified name of the class.
  Shortcut is the shortened form to use for this class
    (usually the class name without the package). }
procedure AddCommonJavaClass(const ClassName, Shortcut: UTF8String);
begin
  if CommonTypes.Values[string(Shortcut)] <> '' then
    raise Exception.Create(Format(ExistingShortcut, [Shortcut]));
  CommonTypes.Values[string(Shortcut)] := string(ClassName);
end;

{ Translate a single Java type into a signature code. For example,
  'boolean' becomes 'Z', 'int' becomes 'I', while classes become 'L<class name>;'.
  JType is the text version of the Java type. }
function GetJavaType(const JType: UTF8String): UTF8String;
var
  Len, ArrayDims: Integer;
  JType2: UTF8String;
  FullName: string;
begin
  JType2    := JType;
  Len       := Length(JType2);
  ArrayDims := 0;
  while (Len > 2) and (Copy(JType2, Len - 1, 2) = '[]') do
  begin
    Inc(ArrayDims);
    Delete(JType2, Len - 1, 2);
    Len := Length(JType2);
  end;
  if JType2 = 'boolean' then
    Result := 'Z'
  else if JType2 = 'byte' then
    Result := 'B'
  else if JType2 = 'char' then
    Result := 'C'
  else if JType2 = 'short' then
    Result := 'S'
  else if JType2 = 'int' then
    Result := 'I'
  else if JType2 = 'long' then
    Result := 'J'
  else if JType2 = 'float' then
    Result := 'F'
  else if JType2 = 'double' then
    Result := 'D'
  else if JType2 = 'void' then
    Result := 'V'
  else
  begin
    FullName := CommonTypes.Values[string(JType2)];
    if FullName = '' then
      FullName := string(JType2);
    Result := UTF8String('L' + StringReplace(FullName, '.', '/', [rfReplaceAll]) + ';');
  end;
  while ArrayDims > 0 do
  begin
    Result := '[' + Result;
    Dec(ArrayDims);
  end;
end;

{ Convert a list of Java types into a method signature. The first entry
  in the list is the return type of the method, which may be 'void'.
  For example, ['void', 'int', 'boolean'] becomes '(IZ)V'.
  JTypes is an array of Java type names. }
function GetJavaMethodSig(const JTypes: array of UTF8String): UTF8String; overload;
var
  Index: Integer;
begin
  Result := '';
  for Index := Succ(Low(JTypes)) to High(JTypes) do
  begin
    Result := Result + GetJavaType(JTypes[Index]);
  end;
  Result := '(' + Result + ')' + GetJavaType(JTypes[Low(JTypes)]);
end;

var
  JTypes: TStringList = nil;

{ Convert a string of Java types into a method signature. The first entry
  in the string is the return type of the method, which may be 'void'.
  For example, 'void (int, boolean)' becomes '(IZ)V'.
  MethodSig is the text for the method return type and parameter types. }
function GetJavaMethodSig(const MethodSig: UTF8String): UTF8String; overload;
var
  JType, Sig: string;
  Index: Integer;
  JTypesA: array of UTF8String;
begin
  JTypes.Clear;
  JType := '';
  Sig := string(MethodSig);
  for Index := 1 to Length(Sig) do
    if Pos(Sig[Index], ' ,()') > 0 then
    begin
      if JType <> '' then
        JTypes.Add(JType);
      JType := '';
    end
    else
      JType := JType + Sig[Index];
  if JType <> '' then
    JTypes.Add(JType);
  SetLength(JTypesA, JTypes.Count);
  for Index := 0 to JTypes.Count - 1 do
    JTypesA[Index] := UTF8String(JTypes[Index]);
  Result := GetJavaMethodSig(JTypesA);
end;

{ Create an instance of a class and return a reference to it,
  or nil if it cannot be created.
  If the class or constructor is not found, or its parameters are incorrect,
  an exception is raised.
  JVM is a reference to the Java environment.
  ClassName is the name of the class to instantiate.
  ConstructorSig is the full text of the constructor's signature.
  Args is an array of items to pass to the constructor upon invocation. }
function CreateObject(const JVM: TJNIEnv;
  const ClassName, ConstructorSig: UTF8String; const Args: array of const): JObject;
var
  Cls: JClass;
  ConstructorId: JMethodID;
begin
  // Find the required class
  Cls := JVM.FindClass(UTF8String(StringReplace(string(ClassName), '.', '/', [rfReplaceAll])));
  if Cls = nil then
    raise EJNIError.Create(ClassNotFound);

  // And its constructor
  ConstructorId := JVM.GetMethodID(Cls, ConstructorName,
    GetJavaMethodSig(ConstructorSig));
  if ConstructorId = nil then
    raise EJNIError.Create(
      Format(MethodNotFound, ['constructor', ConstructorSig]));

  // And create the object
  Result := JVM.NewObjectA(Cls, ConstructorId, JVM.ArgsToJValues(Args));
end;

{ Retrieve the (primitive/string) value of an object/class field.
  If the field is not found, or its type is an object, an exception is raised.
  JVM is a reference to the Java environment.
  Obj is a reference to the class (for static) or object in question.
  FieldName is the name of the field to retrieve.
  FieldType is the full text name of the field's type.
  Static is True is the field is a static attribute of the class,
         or False (the default) is an ordinary attribute of an object. }
function GetFieldValue(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const FieldName, FieldType: UTF8String; const Static: Boolean): Variant;
var
  Cls: JClass;
  JType: UTF8String;
  FID: JFieldId;
begin
  if Static then
    // The object is the class
    Cls := ClsOrObj
  else
    // Get the class associated with this object
    Cls := JVM.GetObjectClass(ClsOrObj);
  if Cls = nil then
    raise EJNIError.Create(ClassNotFound);
  // Get the field
  JType := GetJavaType(FieldType);
  FID   := JVM.GetFieldID(Cls, FieldName, JType);
  if FID = nil then
    raise EJNIError.Create(Format(FieldNotFound, [FieldType, FieldName]));
  // Get the value
  if Static then
    case JType[1] of
      'Z': Result := JVM.GetStaticBooleanField(ClsOrObj, FID);  // boolean
      'B': Result := JVM.GetStaticByteField(ClsOrObj, FID);     // byte
      'C': Result := JVM.GetStaticCharField(ClsOrObj, FID);     // char
      'S': Result := JVM.GetStaticShortField(ClsOrObj, FID);    // short
      'I': Result := JVM.GetStaticIntField(ClsOrObj, FID);      // int
      'J': Result := JVM.GetStaticLongField(ClsOrObj, FID);     // long
      'F': Result := JVM.GetStaticFloatField(ClsOrObj, FID);    // float
      'D': Result := JVM.GetStaticDoubleField(ClsOrObj, FID);   // double
      'L':  // object
        if JType = 'Ljava/lang/String;' then
          Result := JVM.JStringToString(JVM.GetStaticObjectField(ClsOrObj, FID))
        else
          raise EJNIError.Create(Format(NoObjectReturn, [FieldType]));
      else raise EJNIError.Create(Format(UnknownFieldType, [FieldType]));
    end
  else
    case JType[1] of
      'Z': Result := JVM.GetBooleanField(ClsOrObj, FID); // boolean
      'B': Result := JVM.GetByteField(ClsOrObj, FID);    // byte
      'C': Result := JVM.GetCharField(ClsOrObj, FID);    // char
      'S': Result := JVM.GetShortField(ClsOrObj, FID);   // short
      'I': Result := JVM.GetIntField(ClsOrObj, FID);     // int
      'J': Result := JVM.GetLongField(ClsOrObj, FID);    // long
      'F': Result := JVM.GetFloatField(ClsOrObj, FID);   // float
      'D': Result := JVM.GetDoubleField(ClsOrObj, FID);  // double
      'L':  // object
        if JType = 'Ljava/lang/String;' then
          Result := JVM.JStringToString(JVM.GetObjectField(ClsOrObj, FID))
        else
          raise EJNIError.Create(Format(NoObjectReturn, [FieldType]));
      else raise EJNIError.Create(Format(UnknownFieldType, [FieldType]));
    end;
end;

{ Retrieve the (object) value of an object/class field.
  If the field is not found, or its type is a primitive, an exception is raised.
  JVM is a reference to the Java environment.
  ClsOrObj is a reference to the class (for static) or object in question.
  FieldName is the name of the field to retrieve.
  FieldType is the full text name of the field's type.
  Static is True is the field is a static attribute of the class,
         or False (the default) is an ordinary attribute of an object. }
function GetObjectFieldValue(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const FieldName, FieldType: UTF8String; const Static: Boolean): JObject; overload;
var
  Cls: JClass;
  JType: UTF8String;
  FID: JFieldId;
begin
  if Static then
    // The object is the class
    Cls := ClsOrObj
  else
    // Get the class associated with this object
    Cls := JVM.GetObjectClass(ClsOrObj);
  if Cls = nil then
    raise EJNIError.Create(ClassNotFound);
  // Get the field
  JType := GetJavaType(FieldType);
  if JType[1] <> 'L' then
    raise EJNIError.Create(Format(NoPrimitiveReturn, [FieldType]));
  FID := JVM.GetFieldID(Cls, FieldName, JType);
  if FID = nil then
    raise EJNIError.Create(Format(FieldNotFound, [FieldType, FieldName]));
  // Get the value
  if Static then
    Result := JVM.GetStaticObjectField(ClsOrObj, FID)
  else
    Result := JVM.GetObjectField(ClsOrObj, FID);
end;

{ Call a method of an object/class that returns a primitive/string/void.
  If the method is not found, or its return type is an object, an exception is raised.
  JVM is a reference to the Java environment.
  ClsOrObj is a reference to the class (for static) or object in question.
  MethodName is the name of the method to call.
  MethodSig is the full text of the method's signature.
  Args is an array of items to pass to the method upon invocation.
  Static is True is the method is a static attribute of the class,
         or False (the default) is an ordinary attribute of an object. }
function CallMethod(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const MethodName, MethodSig: UTF8String; const Args: array of const;
  const Static: Boolean): Variant;
var
  Cls: JClass;
  JSig, ReturnType: UTF8String;
  MID: JMethodId;
begin
  if Static then
    // The object is the class
    Cls := ClsOrObj
  else
    // Get the class associated with this object
    Cls := JVM.GetObjectClass(ClsOrObj);
  if Cls = nil then
    raise EJNIError.Create(ClassNotFound);
  // Get the method
  JSig := GetJavaMethodSig(MethodSig);
  if Static then
    MID := JVM.GetStaticMethodID(Cls, MethodName, JSig)
  else
    MID := JVM.GetMethodID(Cls, MethodName, JSig);
  if MID = nil then
    raise EJNIError.Create(Format(MethodNotFound, [MethodName, MethodSig]));
  // Get the value
  ReturnType := Copy(JSig, Pos(')', JSig) + 1, Length(JSig));
  Result     := Null;
  if Static then
    case ReturnType[1] of
      'Z': Result := JVM.CallStaticBooleanMethod(ClsOrObj, MID, Args);  // boolean
      'B': Result := JVM.CallStaticByteMethod(ClsOrObj, MID, Args);     // byte
      'C': Result := JVM.CallStaticCharMethod(ClsOrObj, MID, Args);     // char
      'S': Result := JVM.CallStaticShortMethod(ClsOrObj, MID, Args);    // short
      'I': Result := JVM.CallStaticIntMethod(ClsOrObj, MID, Args);      // int
      'J': Result := JVM.CallStaticLongMethod(ClsOrObj, MID, Args);     // long
      'F': Result := JVM.CallStaticFloatMethod(ClsOrObj, MID, Args);    // float
      'D': Result := JVM.CallStaticDoubleMethod(ClsOrObj, MID, Args);   // double
      'V': JVM.CallStaticVoidMethod(ClsOrObj, MID, Args);
      'L':  // object
        if ReturnType = 'Ljava/lang/String;' then
          Result := JVM.JStringToString(
            JVM.CallStaticObjectMethod(ClsOrObj, MID, Args))
        else
          raise EJNIError.Create(
            Format(NoObjectReturn, [Copy(MethodSig, 1, Pos('(', MethodSig) - 1)]));
      else raise EJNIError.Create(Format(UnknownFieldType, [MethodSig]));
    end
  else
    case ReturnType[1] of
      'Z': Result := JVM.CallBooleanMethod(ClsOrObj, MID, Args); // boolean
      'B': Result := JVM.CallByteMethod(ClsOrObj, MID, Args);    // byte
      'C': Result := JVM.CallCharMethod(ClsOrObj, MID, Args);    // char
      'S': Result := JVM.CallShortMethod(ClsOrObj, MID, Args);   // short
      'I': Result := JVM.CallIntMethod(ClsOrObj, MID, Args);     // int
      'J': Result := JVM.CallLongMethod(ClsOrObj, MID, Args);    // long
      'F': Result := JVM.CallFloatMethod(ClsOrObj, MID, Args);   // float
      'D': Result := JVM.CallDoubleMethod(ClsOrObj, MID, Args);  // double
      'V': JVM.CallVoidMethod(ClsOrObj, MID, Args);
      'L':  // object
        if ReturnType = 'Ljava/lang/String;' then
          Result := JVM.JStringToString(JVM.CallObjectMethod(ClsOrObj, MID, Args))
        else
          raise EJNIError.Create(
            Format(NoObjectReturn, [Copy(MethodSig, 1, Pos('(', MethodSig) - 1)]));
      else raise EJNIError.Create(Format(UnknownFieldType, [MethodSig]));
    end;
end;

{ Call a method of an object/class that returns an object.
  If the method is not found, or its return type is not an object, an exception is raised.
  JVM is a reference to the Java environment.
  ClsOrObj is a reference to the class (for static) or object in question.
  MethodName is the name of the method to call.
  MethodSig is the full text of the method's signature.
  Args is an array of items to pass to the method upon invocation.
  Static is True is the method is a static attribute of the class,
         or False (the default) is an ordinary attribute of an object. }
function CallObjectMethod(const JVM: TJNIEnv; const ClsOrObj: JObject;
  const MethodName, MethodSig: UTF8String; const Args: array of const;
  const Static: Boolean): JObject;
var
  Cls: JClass;
  JSig, ReturnType: UTF8String;
  MID: JMethodId;
begin
  if Static then
    // The object is the class
    Cls := ClsOrObj
  else
    // Get the class associated with this object
    Cls := JVM.GetObjectClass(ClsOrObj);
  if Cls = nil then
    raise EJNIError.Create(ClassNotFound);
  // Get the method
  JSig := GetJavaMethodSig(MethodSig);
  if Static then
    MID := JVM.GetStaticMethodID(Cls, MethodName, JSig)
  else
    MID := JVM.GetMethodID(Cls, MethodName, JSig);
  if MID = nil then
    raise EJNIError.Create(Format(MethodNotFound, [MethodName, MethodSig]));
  // Get the value
  ReturnType := Copy(JSig, Pos(')', JSig) + 1, Length(JSig));
  if ReturnType[1] <> 'L' then
    raise EJNIError.Create(
      Format(NoPrimitiveReturn, [Copy(MethodSig, 1, Pos('(', MethodSig) - 1)]));
  if Static then
    Result := JVM.CallStaticObjectMethod(ClsOrObj, MID, Args)
  else
    Result := JVM.CallObjectMethod(ClsOrObj, MID, Args);
end;

initialization
  CommonTypes := TStringList.Create;
  { Set up common Java types for shorthand references }
  CommonTypes.Values['Boolean'] := 'java.lang.Boolean';
  CommonTypes.Values['Byte']    := 'java.lang.Byte';
  CommonTypes.Values['Char']    := 'java.lang.Char';
  CommonTypes.Values['Class']   := 'java.lang.Class';
  CommonTypes.Values['Double']  := 'java.lang.Double';
  CommonTypes.Values['Float']   := 'java.lang.Float';
  CommonTypes.Values['Integer'] := 'java.lang.Integer';
  CommonTypes.Values['Long']    := 'java.lang.Long';
  CommonTypes.Values['Object']  := 'java.lang.Object';
  CommonTypes.Values['Short']   := 'java.lang.Short';
  CommonTypes.Values['String']  := 'java.lang.String';
  JTypes := TStringList.Create;
finalization
  CommonTypes.Free;
  JTypes.Free;
end.
