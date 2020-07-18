package exposer

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"os/exec"

	_ "github.com/lib/pq"
	"github.com/pkg/errors"
)

func Run(dsn string) error {
	db, err := genDB(dsn)
	if err != nil {
		return errors.Wrap(err, "generate db connection error")
	}

	memos, err := fetchMemos(db)
	if err != nil {
		return errors.Wrap(err, "db error")
	}

	if err := genMD(memos); err != nil {
		return errors.Wrap(err, "generate md file error")
	}

	if err := genSite(); err != nil {
		return errors.Wrap(err, "generate html error")
	}

	if err := uploadSite(); err != nil {
		return errors.Wrap(err, "upload site error")
	}

	log.Println("succeeded")
	return nil
}

func genDB(dsn string) (*sql.DB, error) {
	if dsn == "" {
		return nil, errors.New("undefined dsn")
	}

	log.Println("using dsn:", dsn)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, errors.WithStack(err)
	}
	return db, nil
}

type Memo struct {
	subject string
	content string
}

func fetchMemos(db *sql.DB) ([]Memo, error) {
	const sql = `select subject, content from memos where id = 45`

	rows, err := db.Query(sql)
	if err != nil {
		return nil, errors.WithStack(err)
	}

	var memos []Memo
	for rows.Next() {
		var memo Memo
		if err := rows.Scan(&memo.subject, &memo.content); err != nil {
			return nil, errors.WithStack(err)
		}
		memos = append(memos, memo)
	}

	return memos, nil
}

func genMD(memos []Memo) error {
	// TODO: linuxのファイル名で使用できない文字チェック
	fileName := fmt.Sprintf("%s.md", memos[0].subject)

	// hugo new site hogehoge で生成したhogehogeディレクトリ内でhugo new fuga.md　しないと失敗する。
	// 既に同名のmdファイルが存在していた場合、hugo new fuga.mdは失敗する。
	err := exec.Command("hugo", "new", fmt.Sprintf("posts/%s", fileName)).Run()
	if err != nil {
		return errors.WithStack(err)
	}

	dir, err := os.Getwd()
	if err != nil {
		return errors.WithStack(err)
	}
	f, err := os.OpenFile(fmt.Sprintf("%s/content/posts/%s", dir, fileName), os.O_RDWR, 0644)
	if err != nil {
		return errors.WithStack(err)
	}
	defer f.Close()
	// HUGOで生成したmdファイルに、titleへメモのsubjectを書き出すため(4バイト目から)
	title := `title: "` + memos[0].subject + `"`
	_, err = f.WriteAt([]byte(title), 4)
	if err != nil {
		return errors.WithStack(err)
	}
	inf, err := f.Stat()
	if err != nil {
		return errors.WithStack(err)
	}
	// メモのcontentを追記するために、ファイルの最後尾から書き出す(inf.Size())
	_, err = f.WriteAt([]byte(memos[0].content), inf.Size())
	if err != nil {
		return errors.WithStack(err)
	}

	return nil
}

func genSite() error {
	err := exec.Command("hugo", "-D").Run()
	if err != nil {
		return errors.WithStack(err)
	}
	return nil
}

func uploadSite() error {
	err := exec.Command("gsutil", "rsync", "-R", "public", "gs://www.dododo.site").Run()
	if err != nil {
		return errors.WithStack(err)
	}
	return nil
}
