module AvatarHelper
  def avatar_url_for(record, opts = {})
    size = opts[:size] || 48

    if record.respond_to?(:avatar) && record.avatar.attached? && record.avatar.variable?
      record.avatar.variant(resize_to_fit: [size, size])
    else
      gravatar_url_for(record.email, size: size)
    end
  end

  def ui_avatar_url(**options)
    "https://ui-avatars.com/api/?#{options.to_query}"
  end
end
