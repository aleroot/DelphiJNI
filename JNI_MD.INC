{******************************************************************}
{                                                                  }
{       Borland Delphi Runtime Library                             }
{       Java Native Interface Unit                                 }
{                                                                  }
{ Portions created by Sun are                                      }
{ Copyright (C) 1996-1999 Sun Microsystems, Inc.,                  }
{ 901 San Antonio Road, Palo Alto, California, 94303, U.S.A.       }
{ All Rights Reserved.                                             }
{                                                                  }
{ The original file is: jni_md.h, released 21 Sep 1998.            }
{ The original Pascal code is: JNI_MD.INC, released 01 Sep 2000.   }
{                                                                  }
{ Portions created by Matthew Mead are                             }
{ Copyright (C) 2002 MMG and Associates                            }
{                                                                  }
{ Obtained through:                                                }
{ Joint Endeavour of Delphi Innovators (Project JEDI)              }
{                                                                  }
{ You may retrieve the latest version of this file at the Project  }
{ JEDI home page, located at http://delphi-jedi.org                }
{                                                                  }
{ The contents of this file are used with permission, subject to   }
{ the Mozilla Public License Version 1.1 (the "License"); you may  }
{ not use this file except in compliance with the License. You may }
{ obtain a copy of the License at                                  }
{ http://www.mozilla.org/NPL/NPL-1_1Final.html                     }
{                                                                  }
{ Software distributed under the License is distributed on an      }
{ "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or   }
{ implied. See the License for the specific language governing     }
{ rights and limitations under the License.                        }
{                                                                  }
{******************************************************************}

{ These are Windows/Linux specific types. }

type
  JInt  = Integer;
  JLong = Int64;
  JByte = Shortint;
