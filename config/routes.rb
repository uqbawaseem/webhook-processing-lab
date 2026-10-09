Rails.application.routes.draw do
  get "/up", to: "rails/health#show"
  post "/webhooks/sample", to: "webhooks#create"
  get "/events/:id", to: "events#show"
  post "/events/:id/replay", to: "events#replay"
end
