# name: discourse-change-username-cooldown
# about: Allows username change on a cooldown.
# version: 0.0.1

enabled_site_setting :change_username_enabled

module UsernameChangerPatch
    def update_username(attrs = {})
        return super unless SiteSetting.change_username_enabled

        user = User.find(attrs[:user_id])
        user.user_custom_fields.find_or_initialize_by(name: 'username_changed_at').tap do |custom_field|
            custom_field.value = Time.current.iso8601
            custom_field.save
        end

        super
    end
end

module UserGuardianPatch
    def can_edit_username?(user)
        original_result = super

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

after_initialize do
    UsernameChanger.singleton_class.prepend(UsernameChangerPatch)

    UserGuardian.prepend(UserGuardianPatch)

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