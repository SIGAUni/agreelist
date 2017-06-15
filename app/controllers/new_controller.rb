class NewController < ApplicationController
  before_action :set_back_url_to_current_page, only: :index
  def index
    @agreements = Agreement.joins("left join individuals on individuals.id=agreements.individual_id").where("individuals.wikipedia is not null and individuals.wikipedia != ''").order(updated_at: :desc).page(params[:page] || 1).per(50).includes(:statement).includes(:individual)
    @statement = Statement.new
    @influencers = Individual.where("lower(twitter) in (?)", %w(barackobama stephenhawking8 hillaryclinton pontifex billgates oprah elonmusk)).order(ranking: :desc, followers_count: :desc)
  end

  def vote
    agreement = Agreement.where(statement_id: params[:statement_id], individual_id: current_user.id).first
    if agreement
      agreement.extent = extent
    else
      agreement = Agreement.new(
        statement_id: params[:statement_id],
        individual_id: current_user.id,
        extent: params[:vote] == "agree" ? 100 : 0)
    end
    agreement.save
    redirect_to edit_reason_path(agreement) || new_path
  end

  private

  def extent
    params[:vote] == "agree" ? 100 : 0
  end
end
