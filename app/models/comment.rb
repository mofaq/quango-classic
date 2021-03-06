
class Comment
  include MongoMapper::Document
  include Support::Voteable

  key :_id, String
  key :_type, String
  key :body, String, :required => true
  key :language, String, :default => "en"
  key :banned, Boolean, :default => false

  timestamps!

  key :user_id, String, :index => true
  belongs_to :user

  key :group_id, String, :index => true
  belongs_to :group

  key :commentable_id, String
  key :commentable_type, String
  belongs_to :commentable, :polymorphic => true

  validates_presence_of :user

  validate :disallow_spam

  def ban
    self.collection.update({:_id => self.id}, {:$set => {:banned => true}})
  end

  def self.ban(ids)
    ids.each do |id|
      self.collection.update({:_id => id}, {:$set => {:banned => true}})
    end
  end

  def can_be_deleted_by?(user)
    ok = (self.user_id == user.id && user.can_delete_own_comments_on?(self.group)) || user.mod_of?(self.group)
    if !ok && user.can_delete_comments_on_own_items_on?(self.group) && (q = self.find_item)
      ok = (q.user_id == user.id)
    end

    ok
  end

  def find_item
    item = nil
    if self.commentable.kind_of?(Item)
      item = self.commentable
    elsif self.commentable.respond_to?(:item)
      item = self.commentable.item
    end

    item
  end

  def item_id
    item_id = nil

    if self.commentable_type == "Item"
      item_id = self.commentable_id
    elsif self.commentable_type == "Answer"
      item_id = self.commentable.item_id
    elsif self.commentable.respond_to?(:item)
      item_id = self.commentable.item_id
    end

    item_id
  end


  def find_recipient
    if self.commentable.respond_to?(:user)
      self.commentable.user
    end
  end

  protected
  def disallow_spam
    eq_comment = Comment.first({ :body => self.body,
                                  :commentable_id => self.commentable_id
                                })


    valid = (eq_comment.nil? || eq_comment.id == self.id)
    if !valid
      self.errors.add(:body, "Your comment looks like spam.")
    end
  end
end
