require "../../spec_helper"

describe "Type inference: union" do
  it "types union when obj is union" do
    assert_type("struct Char; def +(other); self; end; end; a = 1 || 'a'; a + 1") { union_of(int32, char) }
  end

  it "types union when arg is union" do
    assert_type("struct Int; def +(x : Char); x; end; end; a = 1 || 'a'; 1 + a") { union_of(int32, char) }
  end

  it "types union when both obj and arg are union" do
    assert_type("struct Char; def +(other); self; end; end; struct Int; def +(x : Char); x; end; end; a = 1 || 'a'; a + a") { union_of(int32, char) }
  end

  it "types union of classes" do
    assert_type("class A; end; class B; end; a = A.new || B.new; a") { union_of(types["A"], types["B"]) }
  end

  it "assigns to union and keeps new union type in call" do
    assert_type("
      def foo(x)
        while false
          x = 'a'
        end
        x
      end

      foo(1 || false)
      ") { union_of(int32, bool, char) }
  end

  it "looks up type in union type with free var" do
    assert_type("
      class Bar(T)
      end

      def foo(x : T)
        Bar(T).new
      end

      foo(1 || 'a')
    ") { generic_class "Bar", union_of(int32, char) }
  end

  it "supports ifdef inside union" do
    assert_type(%(
      lib LibC
        union Foo
          ifdef some_flag
            a : Int32
          else
            a : Float64
          end
        end
      end

      LibC::Foo.new.a
      ), flags: "some_flag") { int32 }
  end

  it "types union" do
    assert_type(%(
      Union(Int32, String)
      )) { union_of(int32, string).metaclass }
  end

  it "types union of same type" do
    assert_type(%(
      Union(Int32, Int32, Int32)
      )) { int32.metaclass }
  end

  it "can reopen Union" do
    assert_type(%(
      struct Union
        def self.foo
          1
        end
      end
      Union(Int32, String).foo
      )) { int32 }
  end

  it "can reopen Union and access T" do
    assert_type(%(
      struct Union
        def self.types
          T
        end
      end
      Union(Int32, String).types
      )) { tuple_of([int32, string]).metaclass }
  end

  it "can iterate T" do
    assert_type(%(
      struct Union
        def self.types
          {% begin %}
            {
              {% for type in T %}
                {{type}},
              {% end %}
            }
          {% end %}
        end
      end
      Union(Int32, String).types
      )) { tuple_of([int32.metaclass, string.metaclass]) }
  end

  it "errors if instantiates union" do
    assert_error %(
      Union(Int32, String).new
      ),
      "can't create instance of a union type"
  end

  it "finds method in Object" do
    assert_type(%(
      class Object
        def self.foo
          1
        end
      end

      Union(Int32, String).foo
      )) { int32 }
  end

  it "finds method in Value" do
    assert_type(%(
      struct Value
        def self.foo
          1
        end
      end

      Union(Int32, String).foo
      )) { int32 }
  end

  it "merges types in the same hierarchy with Union" do
    assert_type(%(
      class Foo; end
      class Bar < Foo; end

      Union(Foo, Bar)
      )) { types["Foo"].virtual_type!.metaclass }
  end
end
