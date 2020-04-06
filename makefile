# リモートのDBからデータのみ取得
gendata:
	ssh ochi@ddddddo.work "cd /home/pi/tag-mng/db/bk; pg_dump -U postgres tag-mng -a > data_dump.sql"
	scp ochi@ddddddo.work:/home/pi/tag-mng/db/bk/data_dump.sql /mnt/c/DEV/workspace/GO/src/github.com/ddddddO/tag-mng/_data

# ローカルにpostgresを初期化して起動
localpg:
	# postgresコンテナ起動とともにDATABASE(tag-mng)を作成します
	docker run -d --name local-postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres -v /mnt/c/DEV/workspace/GO/src/github.com/ddddddO/tag-mng/db/create_db:/docker-entrypoint-initdb.d/ postgres:12-alpine
	# 起動したlocalのpostgresコンテナのtag-mngデータベースに対してマイグレートアップします
	sleep 5 && sql-migrate up -config=db/dbconfig.yml
	# 初期化されたDBに対して、初期データを投入します
	PGPASSWORD=postgres psql -h localhost -U postgres -d tag-mng -f _data/data_dump.sql 

	#docker run -d --name local-postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:12-alpine

conlocalpg:
	PGPASSWORD=postgres psql -h localhost -U postgres -d tag-mng

rmlocalpg:
	docker ps -a --filter name=local-postgres -q | xargs docker rm -f

# https://qiita.com/n11sh1/items/5d64c337ef927ac8d5d6  に、以下「key」と「to」の値についてある
#pushnotice:
	curl -X POST -H "Authorization: key=<SERVER KEY>" -H "Content-Type: application/json" -d '{
	"to": "<GENERETED TOKEN>",
	"notification": {
	"title": "FCM Message",
	"body": "This is an FCM Message",
	"icon": "./img/icons/android-chrome-192x192.png"
	}
	}' https://fcm.googleapis.com/fcm/send
