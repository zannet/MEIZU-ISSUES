# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class Member < ActiveRecord::Base
  belongs_to :user
  acts_as_list :scope => :user
  belongs_to :principal, :foreign_key => 'user_id'
  has_many :member_roles, :dependent => :destroy
  has_many :roles, :through => :member_roles  
  has_many :events, :as => :eventable, :dependent => :destroy
    
  belongs_to :project

  validates_presence_of :principal, :project
  validates_uniqueness_of :user_id, :scope => :project_id
  validate :validate_role

  before_destroy :set_issue_category_nil
  after_destroy :unwatch_from_permission_change
  
  before_save :mute_by_project

  def role
  end

  def role=
  end

  def name
    self.user.name
  end
  
  alias :base_role_ids= :role_ids=
  def role_ids=(arg)
    ids = (arg || []).collect(&:to_i) - [0]
    # Keep inherited roles
    ids += member_roles.select {|mr| !mr.inherited_from.nil?}.collect(&:role_id)

    new_role_ids = ids - role_ids
    # Add new roles
    new_role_ids.each {|id| member_roles << MemberRole.new(:role_id => id) }
    # Remove roles (Rails' #role_ids= will not trigger MemberRole#on_destroy)
    member_roles_to_destroy = member_roles.select {|mr| !ids.include?(mr.role_id)}
    if member_roles_to_destroy.any?
      member_roles_to_destroy.each(&:destroy)
      unwatch_from_permission_change
    end
  end

  def <=>(member)
    a, b = roles.sort.first, member.roles.sort.first
    if a == b
      if principal
        principal <=> member.principal
      else
        1
      end
    elsif a
      a <=> b
    else
      1
    end
  end

  def deletable?
    member_roles.detect {|mr| mr.inherited_from}.nil?
  end

  def include?(user)
    if principal.is_a?(Group)
      !user.nil? && user.groups.include?(principal)
    else
      self.user == user
    end
  end

  def set_issue_category_nil
    if user
      # remove category based auto assignments for this member
      IssueCategory.update_all "assigned_to_id = NULL", ["project_id = ? AND assigned_to_id = ?", project.id, user.id]
    end
  end

  # Find or initilize a Member with an id, attributes, and for a Principal
  def self.edit_membership(id, new_attributes, principal=nil)
    @membership = id.present? ? Member.find(id) : Member.new(:principal => principal)
    @membership.attributes = new_attributes
    @membership
  end
  
  
  def self.add_member(project_id=nil,members=nil,description=nil)#add member to planners
    return if project_id.nil? || members.nil?
    exist_members=[]
    Member.find_by_sql("select user_id from members where project_id=#{project_id}").each{|r| exist_members<< r.user_id}
    members.each do |m|
      unless exist_members.include?(m.id)
        member=Member.new(:role_ids => [Role.default.id],:user_id => m.id, :project_id => project_id)
        member.save!
        send_mail(m,project_id,description)
      end
    end
  end
  

  protected

  def validate_role
    errors.add_on_empty :role if member_roles.empty? && roles.empty?
  end
  
  def self.send_mail(member_id,project_id,description)
    Mailer.delay.mail_to_new_member(member_id,project_id,description)
  end
  

  private

  # Unwatch things that the user is no longer allowed to view inside project
  def unwatch_from_permission_change
    if user
      Watcher.prune(:user => user, :project => project)
    end
  end
  
  def mute_by_project
    if self.project.mute?
      self.mute = true
    end  
  end 
     
  
end

