require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Foreign Key" do

  let(:migration) { ::ActiveRecord::Migration }

  context "created with table" do
    before(:all) do
      define_schema(:auto_create => true) do
        create_table :users, :force => true do |t|
          t.string :login
        end
        create_table :comments, :force => true do |t|
          t.integer :user_id
          t.foreign_key :user_id, :users, :id
        end
      end
      class User < ::ActiveRecord::Base ; end
      class Comment < ::ActiveRecord::Base ; end
    end

    it "should report foreign key constraints" do
      expect(Comment.foreign_keys.collect(&:column_names).flatten).to eq([ "user_id" ])
    end

    it "should report reverse foreign key constraints" do
      expect(User.reverse_foreign_keys.collect(&:column_names).flatten).to eq([ "user_id" ])
    end

  end

  if ::ActiveRecord::VERSION::MAJOR.to_i >= 4
    context "with modifications to SQL generated by upstream visit_TableDefinition" do
      before(:each) do
        allow_any_instance_of(ActiveRecord::Base.connection.class.const_get(:SchemaCreation))
          .to receive(:visit_TableDefinition_without_schema_plus)
          .and_return('this is unexpected')
      end

      it "raises an exception when attempting to create a table" do
        expect {
          define_schema(:auto_create => true) do
            create_table :users, :force => true do |t|
              t.string :login
            end
            create_table :comments, :force => true do |t|
              t.integer :user_id
              t.foreign_key :user_id, :users, :id
            end
          end
        }.to raise_error(RuntimeError, /Internal Error: Can't find.*Rails internals have changed/)
      end
    end
  end

  context "modification" do

    before(:all) do
      define_schema(:auto_create => false) do
        create_table :users, :force => true do |t|
          t.string :login
          t.datetime :deleted_at
        end

        create_table :posts, :force => true do |t|
          t.text :body
          t.integer :user_id
          t.integer :author_id
        end

        create_table :comments, :force => true do |t|
          t.text :body
          t.integer :post_id
          t.foreign_key :post_id, :posts, :id
        end
      end
      class User < ::ActiveRecord::Base ; end
      class Post < ::ActiveRecord::Base ; end
      class Comment < ::ActiveRecord::Base ; end
    end


    context "works", :sqlite3 => :skip do

      context "when is added", "posts(author_id)" do

        before(:each) do
          add_foreign_key(:posts, :author_id, :users, :id, :on_update => :cascade, :on_delete => :restrict)
        end

        after(:each) do
          fk = Post.foreign_keys.detect(&its.column_names == %w[author_id])
          remove_foreign_key(:posts, fk.name)
        end

        it "references users(id)" do
          expect(Post).to reference(:users, :id).on(:author_id)
        end

        it "cascades on update" do
          expect(Post).to reference(:users).on_update(:cascade)
        end

        it "restricts on delete" do
          expect(Post).to reference(:users).on_delete(:restrict)
        end

        it "is available in Post.foreign_keys" do
          expect(Post.foreign_keys.collect(&:column_names)).to include(%w[author_id])
        end

        it "is available in User.reverse_foreign_keys" do
          expect(User.reverse_foreign_keys.collect(&:column_names)).to include(%w[author_id])
        end

      end

      context "when is dropped", "comments(post_id)" do

        let(:foreign_key_name) { fk = Comment.foreign_keys.detect(&its.column_names == %w[post_id]) and fk.name }

        before(:each) do
          remove_foreign_key(:comments, foreign_key_name)
        end

        after(:each) do
          add_foreign_key(:comments, :post_id, :posts, :id)
        end

        it "doesn't reference posts(id)" do
          expect(Comment).not_to reference(:posts).on(:post_id)
        end

        it "is no longer available in Post.foreign_keys" do
          expect(Comment.foreign_keys.collect(&:column_names)).not_to include(%w[post_id])
        end

        it "is no longer available in User.reverse_foreign_keys" do
          expect(Post.reverse_foreign_keys.collect(&:column_names)).not_to include(%w[post_id])
        end

      end

      context "when referencing column and column is removed" do

        let(:foreign_key_name) { Comment.foreign_keys.detect { |definition| definition.column_names == %w[post_id] }.name }

        it "should remove foreign keys" do
          remove_foreign_key(:comments, foreign_key_name)
          expect(Post.reverse_foreign_keys.collect { |fk| fk.column_names == %w[post_id] && fk.table_name == "comments" }).to be_empty
        end

      end

      context "when table name is a reserved word" do
        before(:each) do
          migration.suppress_messages do
            migration.create_table :references, :force => true do |t|
              t.integer :post_id, :foreign_key => false
            end
          end
        end

        it "can add, detect, and remove a foreign key without error" do
          migration.suppress_messages do
            expect {
              migration.add_foreign_key(:references, :post_id, :posts, :id)
              foreign_key = migration.foreign_keys(:references).detect{|definition| definition.column_names == ["post_id"]}
              migration.remove_foreign_key(:references, foreign_key.name)
            }.to_not raise_error
          end
        end
      end

    end

    context "raises an exception", :sqlite3 => :only do

      it "when attempting to add" do
        expect {
          add_foreign_key(:posts, :author_id, :users, :id, :on_update => :cascade, :on_delete => :restrict)
        }.to raise_error(NotImplementedError)
      end

      it "when attempting to remove" do
        expect {
          remove_foreign_key(:posts, "dummy")
        }.to raise_error(NotImplementedError)
      end

    end
  end

  protected
  def add_foreign_key(*args)
    migration.suppress_messages do
      migration.add_foreign_key(*args)
    end
    User.reset_column_information
    Post.reset_column_information
    Comment.reset_column_information
  end

  def remove_foreign_key(*args)
    migration.suppress_messages do
      migration.remove_foreign_key(*args)
    end
    User.reset_column_information
    Post.reset_column_information
    Comment.reset_column_information
  end

end
