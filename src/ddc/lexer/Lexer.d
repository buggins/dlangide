// D grammar - according to http://dlang.org/grammar

module ddc.lexer.Lexer;
import ddc.lexer.tokenizer;

/** Lexem type constants */
enum LexemType : ushort {
	UNKNOWN,
	// types
	TYPE,
	TYPE_CTORS,
	TYPE_CTOR,
	BASIC_TYPE,
	BASIC_TYPE_X,
	BASIC_TYPE_2,
	IDENTIFIER_LIST,
	IDENTIFIER,
	TYPEOF,
    // templates
    TEMPLATE_INSTANCE,
    EXPRESSION,
    ALT_DECLARATOR,
}

class Lexem {
	public @property LexemType type() { return LexemType.UNKNOWN; }
}

/** 
    Returns true for  one of keywords: bool, byte, ubyte, short, ushort, int, uint, long, ulong, 
        char, wchar, dchar, float, double, real, ifloat, idouble, ireal, cfloat, cdouble, creal, void 
*/
bool isBasicTypeXToken(Token token) {
	if (token.type != TokenType.KEYWORD)
		return false;
	Keyword id = token.keyword;
	return id == Keyword.BOOL
		|| id == Keyword.BYTE
		|| id == Keyword.UBYTE
		|| id == Keyword.SHORT
		|| id == Keyword.USHORT
		|| id == Keyword.INT
		|| id == Keyword.UINT
		|| id == Keyword.LONG
		|| id == Keyword.ULONG
		|| id == Keyword.CHAR
		|| id == Keyword.WCHAR
		|| id == Keyword.DCHAR
		|| id == Keyword.FLOAT
		|| id == Keyword.DOUBLE
		|| id == Keyword.REAL
		|| id == Keyword.IFLOAT
		|| id == Keyword.IDOUBLE
		|| id == Keyword.IREAL
		|| id == Keyword.CFLOAT
		|| id == Keyword.CDOUBLE
		|| id == Keyword.CREAL
		|| id == Keyword.VOID;
}

/** 
  Single token, one of keywords: bool, byte, ubyte, short, ushort, int, uint, long, ulong, 
  char, wchar, dchar, float, double, real, ifloat, idouble, ireal, cfloat, cdouble, creal, void
*/
class BasicTypeX : Lexem {
	public Token _token;
	public override @property LexemType type() { return LexemType.BASIC_TYPE_X; }
	public this(Token token) 
	in {
		assert(isBasicTypeXToken(token));
	}
	body {
		_token = token;
	}
}

/** 
    Returns true for  one of keywords: const, immutable, inout, shared 
*/
bool isTypeCtorToken(Token token) {
	if (token.type != TokenType.KEYWORD)
		return false;
	Keyword id = token.keyword;
	return id == Keyword.CONST
		|| id == Keyword.IMMUTABLE
		|| id == Keyword.INOUT
		|| id == Keyword.SHARED;
}

/** 
    Single token, one of keywords: const, immutable, inout, shared 
*/
class TypeCtor : Lexem {
	public Token _token;
	public override @property LexemType type() { return LexemType.TYPE_CTOR; }
	public this(Token token)
	in {
		assert(isTypeCtorToken(token));
	}
	body {
		_token = token;
	}
}

/** 
    Zero, one or several keywords: const, immutable, inout, shared 
*/
class TypeCtors : Lexem {
	public TypeCtor[] _list;
	public override @property LexemType type() { return LexemType.TYPE_CTORS; }
	public this(Token token)
	in {
		assert(isTypeCtorToken(token));
	}
	body {
		_list ~= new TypeCtor(token);
	}
	public void append(Token token)
	in {
		assert(isTypeCtorToken(token));
	}
	body {
		_list ~= new TypeCtor(token);
	}
}

/**
    Identifier.
*/
class Identifier : Lexem {
    IdentToken _token;
	public override @property LexemType type() { return LexemType.IDENTIFIER; }
	public this(Token identifier)
	in {
        assert(identifier.type == TokenType.IDENTIFIER);
	}
	body {
        _token = cast(IdentToken)identifier;
	}
}

/**
    Identifier list.

    IdentifierList:
        Identifier
        Identifier . IdentifierList
        TemplateInstance
        TemplateInstance . IdentifierList
 */
class IdentifierList : Lexem {
    public Identifier _identifier;
    public IdentifierList _identifierList;
    public TemplateInstance _templateInstance;
	public override @property LexemType type() { return LexemType.IDENTIFIER_LIST; }
	public this(Token ident, IdentifierList identifierList = null)
	in {
        assert(ident.type == TokenType.IDENTIFIER);
	}
	body {
        _identifier = new Identifier(ident);
        _identifierList = identifierList;
	}
	public this(TemplateInstance templateInstance, IdentifierList identifierList = null)
	in {
	}
	body {
        _templateInstance = templateInstance;
        _identifierList = identifierList;
	}
}

/**
    Template instance.

    TemplateInstance:
        Identifier TemplateArguments
*/
class TemplateInstance : Lexem {
	public override @property LexemType type() { return LexemType.TEMPLATE_INSTANCE; }
	public this()
	in {
	}
	body {
	}
}

/**
    Basic type.

    BasicType:
        BasicTypeX
        . IdentifierList
        IdentifierList
        Typeof
        Typeof . IdentifierList
        TypeCtor ( Type )
*/
class BasicType : Lexem {
    public BasicTypeX _basicTypeX;
    public IdentifierList _identifierList;
    public Typeof _typeof;
    public TypeCtor _typeCtor;
    public Type _typeCtorType;
    public bool _dotBeforeIdentifierList;
	public override @property LexemType type() { return LexemType.BASIC_TYPE; }
	public this()
	in {
	}
	body {
	}
}



/**
    Typeof.

    Typeof:
        typeof ( Expression )
        typeof ( return )
    
    For typeof(return), _expression is null
*/
class Typeof : Lexem {
    public Expression _expression;
	public override @property LexemType type() { return LexemType.TYPEOF; }
	public this(Expression expression)
	in {
	}
	body {
        _expression = expression;
	}
}

/**
    Type.

*/
class Type : Lexem {
    public TypeCtors _typeCtors;
    public BasicType _basicType;
    public AltDeclarator _altDeclarator;
	public override @property LexemType type() { return LexemType.TYPE; }
	public this()
	in {
	}
	body {
	}
}

/**
    Expression.

    Expression:
*/
class Expression : Lexem {
	public override @property LexemType type() { return LexemType.EXPRESSION; }
	public this()
	in {
	}
	body {
	}
}

/**
    AltDeclarator.

    AltDeclarator:
*/
class AltDeclarator : Lexem {
	public override @property LexemType type() { return LexemType.ALT_DECLARATOR; }
	public this()
	in {
	}
	body {
	}
}

class Lexer
{
}
