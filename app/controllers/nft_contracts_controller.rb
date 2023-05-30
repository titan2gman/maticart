class NftContractsController < ApplicationController
  skip_before_action :authenticate_user, only: [:show]
  skip_before_action :is_approved, only: [:show]
  skip_before_action :verify_authenticity_token


  def show
    @contract = NftContract.where.not(is_shared: true).where(address: params[:id]).first
    unless @contract.present?
      redirect_path = request.referer.present? ? request.referer : root_path
      redirect_to redirect_path, alert: 'Invalid contract address!' and return  
    end
    @tokens = @contract.collections.order("created_at desc").paginate(page: params[:page], per_page: 20)
  end
end
