require 'pg'

class Model
  # pg: http://www.ownway.info/Ruby/pg/about
  def initialize()
    puts 'connect postgres'
    
    @conn = PG::connect(
        host:     'localhost',
        user:     'postgres',
        password: 'postgres',
        dbname:   'tag-mng'
    )
  end

  def login(name, passwd)
    q = 'SELECT id FROM users WHERE name=$1 AND passwd=$2'
    rslt = @conn.exec(q, [name, passwd])
    
    # TODO: 要リファクタ&認証エラーハンドル(401)
    if !rslt.nil?
      user_id = ''
      rslt.each do |row|
        user_id = row['id']
      end

      if !user_id.empty?
        return user_id
      end
    else
      return 'failed to login'
    end
    return 'failed to login'
  end

  def list(user_id, tag_id)
    rslt = []
    if tag_id.empty?
      q = 'SELECT id, subject FROM memos WHERE users_id=$1 ORDER BY id'  
      rslt = @conn.exec(q, [user_id])
    else
      q = 'SELECT id, subject FROM memos WHERE users_id=$1 AND id IN (SELECT memos_id FROM memo_tag WHERE tags_id=$2) ORDER BY id'
      rslt = @conn.exec(q, [user_id, tag_id])
    end

    rows = []
    rslt.each do |row|
      rows.push(row)
    end
    rows
  end

  # タグは別個のSQLでidとnameを取得してrowに詰めて渡した方がいいかも
  def detail(memo_id, user_id)
    select_memo_query = <<~EOS
      SELECT DISTINCT
        m.id AS id,
        m.subject AS subject,
        m.content AS content
      FROM memos m JOIN memo_tag mt 
      ON m.id = mt.memos_id WHERE m.id = $1 AND m.users_id = $2;
    EOS

    select_memo_rslt = @conn.exec(select_memo_query, [memo_id, user_id])

    memos = []
    select_memo_rslt.each do |row|
      memos.push(row)
    end

    select_tags_query = <<~EOS
      SELECT t.id, t.name 
      FROM tags t
      JOIN memo_tag mt
      ON t.id = mt.tags_id
      WHERE mt.memos_id = $1
    EOS

    select_tags_rslt = @conn.exec(select_tags_query, [memo_id])

    tags = []
    select_tags_rslt.each do |row|
      tags.push(row)
    end

    return memos, tags
  end

  # TODO: トランザクションはる
  # TODO: 関数に分割する
  def update(args)
    # メモ新規作成時
    if args['memo_id'].empty?
      insert_memo_query = <<~EOS
        INSERT INTO memos(subject, content, users_id)
        VALUES($1, $2, $3)
        RETURNING id
      EOS

      insert_memo_rslt = @conn.exec(insert_memo_query, [
        args['subject'],
        args['content'],
        args['user_id']
      ])
      inserted_memo_id = insert_memo_rslt[0]['id']

      # メモ新規・編集共通
      if args.key?('new_tag') && !args['new_tag'].empty? # メモに紐づく新規タグを登録する場合
        insert_tag_query = 'INSERT INTO tags(name, users_id) VALUES($1, $2) RETURNING id'

        insert_tag_rslt = @conn.exec(insert_tag_query, [
          args['new_tag'],
          args['user_id']
        ])

        insert_memo_tag_query = 'INSERT INTO memo_tag(memos_id, tags_id) VALUES($1, $2)'

        @conn.exec(insert_memo_tag_query, [
          inserted_memo_id,
          insert_tag_rslt[0]['id']
        ])
      end

      # ユーザーに紐づく(予め登録済みの)タグをメモに登録する場合
      if args.key?('update_tag_ids')
        insert_memo_tag_selected_tag_query = 'INSERT INTO memo_tag(memos_id, tags_id) VALUES($1, $2)'

        args['update_tag_ids'].each do |id|
          @conn.exec(insert_memo_tag_selected_tag_query, [
            inserted_memo_id,
            id
          ])
        end
      end

      return inserted_memo_id
    
    # メモ編集時
    else
      update_memo_query = <<~EOS
        UPDATE memos SET subject=$1, content=$2
        WHERE id=$3 AND users_id=$4
        RETURNING id
      EOS

      update_memo_rslt = @conn.exec(update_memo_query, [
        args['subject'],
        args['content'],
        args['memo_id'],
        args['user_id']
      ])
      updated_memo_id = update_memo_rslt[0]['id']

      # メモに紐づくタグをメモから削除する場合
      # TODO: ループで削除するのではなく、、
      if args.key?('delete_tag_ids')
        delete_tag_from_memo_query = 'DELETE FROM memo_tag WHERE memos_id=$1 AND tags_id=$2'

        args['delete_tag_ids'].each do |id|
          @conn.exec(delete_tag_from_memo_query,[
            updated_memo_id,
            id
          ])
        end
      end

      # メモ新規・編集共通
      if args.key?('new_tag') && !args['new_tag'].empty? # メモに紐づく新規タグを登録する場合
        insert_tag_query = 'INSERT INTO tags(name, users_id) VALUES($1, $2) RETURNING id'

        insert_tag_rslt = @conn.exec(insert_tag_query, [
          args['new_tag'],
          args['user_id']
        ])

        insert_memo_tag_query = 'INSERT INTO memo_tag(memos_id, tags_id) VALUES($1, $2)'

        @conn.exec(insert_memo_tag_query, [
          updated_memo_id,
          insert_tag_rslt[0]['id']
        ])
      end

      # ユーザーに紐づく(予め登録済みの)タグをメモに登録する場合
      if args.key?('update_tag_ids')
        insert_memo_tag_selected_tag_query = 'INSERT INTO memo_tag(memos_id, tags_id) VALUES($1, $2)'

        args['update_tag_ids'].each do |id|
          @conn.exec(insert_memo_tag_selected_tag_query, [
            updated_memo_id,
            id
          ])
        end
      end

      return updated_memo_id
    end
  end

  def fetch_all_tags_of_user(user_id)
    q = 'SELECT id, name FROM tags WHERE users_id = $1 ORDER BY id'

    rslt = @conn.exec(q, [user_id])

    rows = []
    rslt.each do |row|
      rows.push(row)
    end
    rows
  end

  def fetch_all_tags_of_user_excluded_binded_tags(user_id, memo_id)
    q = <<~EOS
      SELECT id, name 
      FROM tags 
      WHERE users_id = $1 
      AND id NOT IN (
        SELECT tags_id 
        FROM memo_tag 
        WHERE memos_id = $2
      )
      ORDER BY id
    EOS

    rslt = @conn.exec(q, [user_id, memo_id])

    rows = []
    rslt.each do |row|
      rows.push(row)
    end
    rows
  end

  def tags(user_id)
    q = 'SELECT id, name FROM tags WHERE users_id = $1 ORDER BY id'
  
    rslt = @conn.exec(q, [user_id])
    
    rows = []
    rslt.each do |row|
      rows.push(row)
    end
    rows
  end
end