module Scim
  class Visitor
    def self.result_for(tree)
      attr = SCIM::User::ATTRIBUTES[tree[:attribute].to_s] || tree[:attribute].to_s
      case tree[:operator].to_s
      when 'or'
        result_for(tree[:left]).or(result_for(tree[:right]))
      when 'eq'
        User.where(attr => tree[:value].to_s[1..-2])
      when 'ne'
        User.where.not(attr => tree[:value].to_s[1..-2])
      else
        User.none
      end
    end
  end
end
