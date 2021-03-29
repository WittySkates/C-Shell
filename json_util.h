#pragma once

#include <string>
#include <vector>

struct keyval_t;

struct object_t {
	/*
	JSON objects can either be simple data types or composite data types
	(objects in objects). We'll use the boolean to denote whether this object
	has children or not. It's up to the programmer to enforce this convention.
	*/
	bool is_composite;
	std::vector<keyval_t>* children;
	std::string* data;
};

struct keyval_t {
	std::string* key;
	object_t value;
};

/*
Some constructors for our JSON types.
*/
object_t make_simple_object(std::string* data);
object_t make_composite_object(std::vector<keyval_t>* children);
keyval_t make_keyval(std::string* key, object_t value);
