clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(script_dir, 'results_step8_7_6_observable_dispatch_demo');
summary_csv_path = fullfile(result_dir, 'step8_7_6_observable_dispatch_demo_summary.csv');

T = readtable(summary_csv_path, 'TextType', 'string');
O = T(T.route_name == "observable_dispatch", :);

make_success_plot_local(O, fullfile(result_dir, 'observable_vs_oracle_dispatch_success.png'));
make_agreement_plot_local(O, fullfile(result_dir, 'observable_route_agreement.png'));
make_low_conf_plot_local(O, fullfile(result_dir, 'observable_low_confidence_rate.png'));
make_false_conf_plot_local(O, fullfile(result_dir, 'observable_false_high_confidence.png'));
make_group_success_plot_local(O, fullfile(result_dir, 'observable_dispatch_by_scenario_group.png'));

function make_success_plot_local(T, path_out)
    [groups, ~, gidx] = unique(T.group, 'stable');
    vals = zeros(numel(groups), 2);
    for ig = 1:numel(groups)
        vals(ig, 1) = mean(T.oracle_dispatch_success_rate(gidx == ig), 'omitnan');
        vals(ig, 2) = mean(T.observable_dispatch_success_rate(gidx == ig), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('joint success rate');
    title('Oracle vs observable dispatch success');
    legend({'oracle', 'observable'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function make_agreement_plot_local(T, path_out)
    snrs = unique(T.snr_db).';
    groups = unique(T.group, 'stable');
    fig = figure('Visible', 'off');
    hold on
    for ig = 1:numel(groups)
        y = nan(size(snrs));
        for is = 1:numel(snrs)
            mask = T.group == groups(ig) & T.snr_db == snrs(is);
            y(is) = mean(T.route_agreement_rate(mask), 'omitnan');
        end
        plot(snrs, y, '-o', 'LineWidth', 1.2);
    end
    grid on
    ylim([-0.05, 1.05]);
    xlabel('SNR (dB)');
    ylabel('route agreement rate');
    title('Observable route agreement');
    legend(cellstr(groups), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function make_low_conf_plot_local(T, path_out)
    [groups, ~, gidx] = unique(T.group, 'stable');
    vals = zeros(numel(groups), 1);
    for ig = 1:numel(groups)
        vals(ig) = mean(T.dispatch_low_confidence_rate(gidx == ig), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('low-confidence rate');
    title('Observable low-confidence rate');
    saveas(fig, path_out);
    close(fig);
end

function make_false_conf_plot_local(T, path_out)
    [groups, ~, gidx] = unique(T.group, 'stable');
    vals = zeros(numel(groups), 2);
    for ig = 1:numel(groups)
        vals(ig, 1) = mean(T.false_high_confidence_rate(gidx == ig), 'omitnan');
        vals(ig, 2) = mean(T.false_medium_high_confidence_rate(gidx == ig), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('rate');
    title('Observable false confidence');
    legend({'false_high', 'false_medium_high'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function make_group_success_plot_local(T, path_out)
    [groups, ~, gidx] = unique(T.group, 'stable');
    snrs = unique(T.snr_db).';
    vals = zeros(numel(groups), numel(snrs));
    for ig = 1:numel(groups)
        for is = 1:numel(snrs)
            mask = gidx == ig & T.snr_db == snrs(is);
            vals(ig, is) = mean(T.joint_tol_success_rate(mask), 'omitnan');
        end
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('joint success rate');
    title('Observable dispatch by scenario group');
    legend(compose('SNR=%g', snrs), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end
