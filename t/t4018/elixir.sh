#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'elixir: do not pick end' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defmodule RIGHT do
EOF_HUNK
defmodule RIGHT do
end
#
#
# ChangeMe; do not pick up 'end' line
EOF_TEST

test_diff_funcname 'elixir: ex unit test' \
	8<<\EOF_HUNK 9<<\EOF_TEST
test "RIGHT" do
EOF_HUNK
defmodule Test do
  test "RIGHT" do
    assert true == true
    assert ChangeMe
  end
end
EOF_TEST

test_diff_funcname 'elixir: function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
def function(RIGHT, arg) do
EOF_HUNK
def function(RIGHT, arg) do
  # comment
  # comment
  ChangeMe
end
EOF_TEST

test_diff_funcname 'elixir: macro' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defmacro foo(RIGHT) do
EOF_HUNK
defmacro foo(RIGHT) do
  # Code
  # Code
  ChangeMe
end
EOF_TEST

test_diff_funcname 'elixir: module' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defmodule RIGHT do
EOF_HUNK
defmodule RIGHT do
  @moduledoc """
  Foo bar
  """

  def ChangeMe(a) where is_map(a) do
    a
  end
end
EOF_TEST

test_diff_funcname 'elixir: module func' \
	8<<\EOF_HUNK 9<<\EOF_TEST
def fun(RIGHT) do
EOF_HUNK
defmodule Foo do
  def fun(RIGHT) do
     # Code
     # Code
     # Code
     ChangeMe
  end
end
EOF_TEST

test_diff_funcname 'elixir: nested module' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defmodule MyApp.RIGHT do
EOF_HUNK
defmodule MyApp.RIGHT do
  @moduledoc """
  Foo bar
  """

  def ChangeMe(a) where is_map(a) do
    a
  end
end
EOF_TEST

test_diff_funcname 'elixir: private function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defp function(RIGHT, arg) do
EOF_HUNK
defp function(RIGHT, arg) do
  # comment
  # comment
  ChangeMe
end
EOF_TEST

test_diff_funcname 'elixir: protocol' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defprotocol RIGHT do
EOF_HUNK
defprotocol RIGHT do
  @doc """
  Calculates the size (and not the length!) of a data structure
  """
  def size(data, ChangeMe)
end
EOF_TEST

test_diff_funcname 'elixir: protocol implementation' \
	8<<\EOF_HUNK 9<<\EOF_TEST
defimpl RIGHT do
EOF_HUNK
defimpl RIGHT do
  # Docs
  # Docs
  def foo(ChangeMe), do: :ok
end
EOF_TEST
