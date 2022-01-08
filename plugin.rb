# name: discourse-change-username-cooldown
# about: Allows username change on a cooldown.
# version: 0.0.1

enabled_site_setting :change_username_enabled

after_initialize do
    require 'action_view'

    UserGuardian.module_eval do
        original_can_edit_username = instance_method(:can_edit_username?)

        define_method(:can_edit_username?) do |user|
            original_result = original_can_edit_username.bind(self).(user)

            return original_result unless SiteSetting.change_username_enabled

            unless original_result
                return false unless is_me?(user)

                last_changed = user.user_custom_fields.find_by(name: 'username_changed_at')&.value

                if last_changed.nil?
                    return true
                else
                    last_changed = DateTime.parse(last_changed)
                    cooldown = SiteSetting.change_username_cooldown.days

                    return Time.current >= last_changed + cooldown
                end
            end

            original_result
        end
    end

    add_to_serializer(:user, :username_changed_at) do
        object.user_custom_fields.find_by(name: 'username_changed_at')&.value
    end

    add_to_serializer(:user, :username_change_available_on) do
        last_changed = object.user_custom_fields.find_by(name: 'username_changed_at')&.value

        unless last_changed.nil?
            last_changed = DateTime.parse(last_changed)
            cooldown = SiteSetting.change_username_cooldown.days

            last_changed + cooldown
        end
    end

    on(:username_changed) do |old_username, new_username|
        return unless SiteSetting.change_username_enabled

        user = User.find_by(username: new_username)

        user.user_custom_fields.find_or_initialize_by(name: 'username_changed_at').tap do |custom_field|
            custom_field.value = Time.current.iso8601
            custom_field.save
        end
    end
end