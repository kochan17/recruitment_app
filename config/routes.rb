Rails.application.routes.draw do
  resources :resumes, only: [:new, :create, :show]
  root 'resumes#new'
end
