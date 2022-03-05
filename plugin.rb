# name: discourse-change-username-cooldown
# about: Allows username change on a cooldown.
# version: 0.0.1

enabled_site_setting :change_username_enabled

after_initialize do
    UsernameChanger.class_eval do
        original_update_username = singleton_method(:update_username)

        define_singleton_method(:update_username) do |attrs|
            return original_update_username.call(attrs) unless SiteSetting.change_username_enabled

            user = User.find(attrs[:user_id])
            user.user_custom_fields.find_or_initialize_by(name: 'username_changed_at').tap do |custom_field|
                custom_field.value = Time.current.iso8601
                custom_field.save
            end

            original_update_username.call(attrs)
        end
    end

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
end