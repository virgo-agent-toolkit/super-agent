default: clean serve

reset-db:
	cat db/0-reset.sql | psql
	cat db/1-create-tables.sql | psql
	luvit db/2-gen-data.lua | psql

deps:
	lit install

serve: deps
	luajit main.lua

clean:
	rm -rf deps
