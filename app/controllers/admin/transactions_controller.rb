class Admin::TransactionsController < Admin::BaseController
  def index
    @transactions = if params[:from_date].present? && params[:to_date].present?
      Transaction.where(created_at: params[:from_date].to_date..params[:to_date].to_date)
    else
      Transaction.all
    end
    @transactions = if params[:sort_by].present?
      @transactions.order("created_at #{params[:sort_by] == 'latest' ? 'desc' : 'asc'}").paginate(page: params[:page], per_page: 10)
    else
      @transactions = @transactions.order("created_at desc").paginate(page: params[:page], per_page: 10)
    end
  end
end
